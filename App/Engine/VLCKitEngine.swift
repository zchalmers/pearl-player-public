import AVFoundation
import MediaPlayer
import PearlKit
import UIKit
import VLCKit

/// The VLCKit (libvlc 4.0) engine. Everything the player screen can do goes
/// through `PlayerEngine`, so this file is the only place that knows VLCKit
/// exists. That is deliberate: libvlc gives the containers (MKV), the subtitle
/// formats (libass ASS/SSA, image subs), the track selection, the network
/// protocols and the renderers in one dependency, and AVPlayer cannot replace
/// any of that.
@MainActor
final class VLCKitEngine: NSObject, PlayerEngine {
    // MARK: - Engine objects

    /// libvlc renders here. Kept private and exposed as `renderView` because a
    /// protocol requirement of type `UIView` cannot be satisfied by a property
    /// of a subclass type.
    private let host: VLCVideoHost
    var renderView: UIView { host.view }

    private let pipController = PictureInPictureController()
    private let library: VLCLibrary
    private let listPlayer: VLCMediaListPlayer
    private let bridge = VLCKitEventBridge()
    /// VLCKit hands its delegate callbacks to whatever queue this configuration
    /// names. `VLCEventsDefaultConfiguration` names no queue and is not async,
    /// so the callbacks run synchronously on a libvlc input thread. Under
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor` the bridge below is main actor
    /// isolated, so a delegate call from a libvlc thread trips the Swift
    /// concurrency runtime and kills the app with SIGTRAP
    /// (`dispatch_assert_queue` through `swift_task_checkIsolatedSwift`, seen in
    /// a device crash report right after a play tap). The legacy configuration
    /// is the one that dispatches asynchronously on the main queue, which is
    /// what every callback in this file expects.
    private var eventsConfiguration = VLCEventsLegacyConfiguration()

    /// VLCKit's own documentation says the framework does not support multiple
    /// `VLCLibrary` instances, so there is exactly one per process no matter how
    /// many engines come and go. Creating one per engine crashed the test host
    /// when a second stream was opened, which is exactly what a user does when
    /// they go back and pick something else.
    private static let sharedLibrary: VLCLibrary = {
        // Main queue callbacks, see the note on `eventsConfiguration`.
        VLCLibrary.sharedEventsConfiguration = VLCEventsLegacyConfiguration()
        let library = VLCLibrary(options: [
            "--no-color",
            "--no-video-title-show",
            "--no-snapshot-preview"
            // no --quiet: the loggers below never see a message otherwise, and
            // the point of this build is to see why a stream stalls.
        ])
        library.setHumanReadableName("Pearl Player", withHTTPUserAgent: "PearlPlayer/1.0")
        // Info level is what reports the demuxer, the access module and every
        // network error, which is what a stalled stream hides.
        library.loggers = [RemoteLog.shared]
        return library
    }()

    private var player: VLCMediaPlayer {
        listPlayer.mediaPlayer
    }

    // MARK: - State

    weak var delegate: (any PlayerEngineDelegate)?
    private(set) var state: PlaybackState = .idle
    private(set) var currentRequest: PlayRequest?
    private(set) var tracks: [TrackInfo] = []
    private(set) var stats: PlaybackStats = .empty

    /// Playback speed the user chose. Restored after a hold gesture ends.
    var rate: Float = 1 {
        didSet { applyRate() }
    }

    private var temporaryRate: Float?
    private var statsTask: Task<Void, Never>?
    private var lastDisplayedPictures: UInt64 = 0
    private var lastStatsDate = Date()
    private var displayFPS: Double = 0

    private var networkCachingMilliseconds = 4000
    private var hardwareDecodingEnabled = true
    private var extraHeaders: [String: String] = [:]
    private var aspectRatio: AspectRatioMode = .fit

    // MARK: - Init

    override init() {
        host = VLCVideoHost()
        library = Self.sharedLibrary
        listPlayer = VLCMediaListPlayer(drawable: host)
        super.init()

        bridge.engine = self
        player.delegate = bridge
        player.drawable = host
        host.mediaControllerProvider = pipController
        pipController.engine = self
        configureAudioSession()
    }

    // MARK: - Loading

    func load(_ request: PlayRequest) {
        RemoteLog.note("load \(request.url.absoluteString) origin=\(request.origin.rawValue)")
        currentRequest = request
        extraHeaders = request.httpHeaders
        setState(.loading)

        if let start = request.startAt, start > 0 {
            pendingStart = start
        }

        // Always assign the media list first, then play. Calling
        // `playMedia:` on a list player that never had a list crashes inside
        // libvlc: `libvlc_media_list_player_play_item` locks the internal list,
        // which is NULL until `mediaList` is set, and the lock dereferences 0x4.
        // Confirmed from a captured crash report.
        let urls = request.playlist?.map(\.url) ?? [request.url]
        let medias = urls.compactMap { makeMedia(for: $0) }
        guard !medias.isEmpty else {
            setState(.failed("Pearl could not open that stream."))
            return
        }
        listPlayer.mediaList = VLCMediaList(array: medias)
        RemoteLog.note("media list set with \(medias.count) item(s), calling play")
        listPlayer.play()
        startStatsTicker()
    }

    private var pendingStart: TimeInterval?

    /// `VLCMedia`'s initialiser is failable: it returns nil when libvlc cannot
    /// make sense of the URL at all.
    private func makeMedia(for url: URL) -> VLCMedia? {
        guard let media = VLCMedia(url: url) else { return nil }
        media.addOption("network-caching=\(networkCachingMilliseconds)")
        media.addOption("file-caching=\(networkCachingMilliseconds)")
        media.addOption(":no-video-title-show")
        for (name, value) in extraHeaders {
            media.addOption("\(name.lowercased())=\(value)")
        }
        if !hardwareDecodingEnabled {
            media.addOption(":avcodec-hw=none")
        }
        return media
    }

    // MARK: - Transport

    func play() {
        // A list player with no list crashes libvlc on play, so an engine that
        // was shut down, or never loaded, simply does nothing. Shutdown leaves
        // an empty list in place (nil trips a libvlc assert there), so the
        // guard is on emptiness, not on the property being nil.
        guard let mediaList = listPlayer.mediaList, !mediaList.isEmpty else { return }
        if state == .ended {
            seek(to: 0)
        }
        listPlayer.play()
    }

    func pause() {
        listPlayer.pause()
    }

    func stop() {
        listPlayer.stop()
        stopStatsTicker()
        setState(.idle)
    }

    /// Deterministic teardown, and the reason it exists: VLCKit runs
    /// `playMedia:` on a worker queue, so releasing the engine while that block
    /// is in flight segfaults inside `libvlc_media_list_lock` on freed memory
    /// (confirmed from a captured crash report: EXC_BAD_ACCESS at 0x4 through
    /// `-[VLCMediaListPlayer playMedia:]_block_invoke`). Stop, drop the list and
    /// detach the drawable before the object goes away, then leave the shared
    /// library alone because it belongs to the process, not to one engine.
    ///
    /// The list is dropped by replacing it, not by assigning nil: this libvlc
    /// asserts inside `libvlc_media_list_player_set_media_list` on a NULL
    /// `p_mlist` (`Assertion failed: (p_mlist), media_list_player.c:466`), so
    /// `mediaList = nil` kills the process instead of releasing the list.
    func shutdown() {
        stopStatsTicker()
        listPlayer.stop()
        listPlayer.mediaList = VLCMediaList(array: [])
        player.delegate = nil
        player.drawable = nil
        bridge.engine = nil
        currentRequest = nil
        tracks = []
        setState(.idle)
    }

    func seek(to time: TimeInterval) {
        let clamped = SeekMath.clampSeek(time, duration: duration)
        player.time = VLCTime(int: Int32(clamped * 1000))
        publishTime()
    }

    func seek(by offset: TimeInterval) {
        seek(to: currentTime + offset)
    }

    func setTemporaryRate(_ newRate: Float?) {
        temporaryRate = newRate
        applyRate(announce: false)
    }

    private func applyRate(announce: Bool = true) {
        let value = temporaryRate ?? rate
        player.rate = value
        if announce {
            objectWillChangeRate?(value)
        }
    }

    /// Set by the view model so a hold gesture can show its speed badge.
    var objectWillChangeRate: ((Float) -> Void)?

    // MARK: - Readback

    var currentTime: TimeInterval {
        TimeInterval(player.time.intValue) / 1000
    }

    var duration: TimeInterval {
        TimeInterval(player.media?.length.intValue ?? 0) / 1000
    }

    var isPlaying: Bool { player.isPlaying }
    var isSeekable: Bool { player.isSeekable }
    var videoSize: CGSize { player.videoSize }

    // MARK: - Picture in Picture

    var isPictureInPictureAvailable: Bool { host.isPictureInPictureAvailable }
    var isPictureInPictureActive: Bool { host.isPictureInPictureActive }

    func startPictureInPicture() {
        host.startPictureInPicture()
    }

    func stopPictureInPicture() {
        host.stopPictureInPicture()
    }

    // MARK: - Tracks

    func selectAudioTrack(id: String) {
        guard let track = player.audioTracks.first(where: { $0.trackId == id }) else { return }
        track.isSelectedExclusively = true
        refreshTracks()
    }

    func selectSubtitleTracks(ids: [String]) {
        let chosen = player.textTracks.filter { ids.contains($0.trackId) }
        guard !chosen.isEmpty else {
            disableSubtitles()
            return
        }
        player.selectTextTracks(chosen)
        refreshTracks()
    }

    func disableSubtitles() {
        player.deselectAllTextTracks()
        refreshTracks()
    }

    func addSubtitleFile(url: URL, title: String?) {
        _ = player.addPlaybackSlave(url, type: .subtitle, enforce: true)
        refreshTracks()
    }

    func setSubtitleDelay(_ seconds: TimeInterval) {
        // VLCKit forwards straight to libvlc_video_set_spu_delay, whose unit is
        // microseconds.
        player.currentVideoSubTitleDelay = NSInteger(seconds * 1_000_000)
    }

    func setAudioDelay(_ seconds: TimeInterval) {
        // Same story: libvlc_audio_set_delay takes microseconds.
        player.currentAudioPlaybackDelay = NSInteger(seconds * 1_000_000)
    }

    private func refreshTracks() {
        var result: [TrackInfo] = []
        for track in player.audioTracks {
            result.append(
                TrackInfo(
                    id: track.trackId,
                    kind: .audio,
                    name: track.trackName.isEmpty ? (track.trackDescription ?? "Audio") : track.trackName,
                    language: track.language,
                    codec: track.codecName(),
                    channels: track.audio.map { Int($0.channelsNumber) },
                    bitrate: track.bitrate > 0 ? Int(track.bitrate) : nil,
                    isSelected: track.isSelected
                )
            )
        }
        for track in player.textTracks {
            result.append(
                TrackInfo(
                    id: track.trackId,
                    kind: .subtitle,
                    name: track.trackName.isEmpty ? (track.trackDescription ?? "Subtitle") : track.trackName,
                    language: track.language,
                    codec: track.codecName(),
                    isSelected: track.isSelected
                )
            )
        }
        tracks = result
        delegate?.engine(self, didUpdateTracks: result)
    }

    // MARK: - Video output

    func setAspectRatio(_ mode: AspectRatioMode) {
        aspectRatio = mode
        switch mode {
        case .fit:
            player.videoFitMode = .smaller
            player.videoAspectRatio = nil
        case .fill:
            player.videoFitMode = .larger
            player.videoAspectRatio = nil
        case .stretch:
            player.videoAspectRatio = "\(Int(videoSize.width)):\(Int(videoSize.height))"
        case .original:
            player.videoAspectRatio = ""
        default:
            player.videoFitMode = .smaller
            player.videoAspectRatio = mode.vlcAspectRatio
        }
    }

    func setScaleFactor(_ factor: Float) {
        player.scaleFactor = factor
    }

    func setDeinterlace(_ enabled: Bool) {
        player.setDeinterlace(enabled ? .on : .off, withFilter: "yadif")
    }

    func setVideoAdjustment(brightness: Float, contrast: Float, saturation: Float, hue: Float, gamma: Float) {
        let filter = player.adjustFilter
        filter.brightness.value = NSNumber(value: brightness)
        filter.contrast.value = NSNumber(value: contrast)
        filter.saturation.value = NSNumber(value: saturation)
        filter.hue.value = NSNumber(value: hue)
        filter.gamma.value = NSNumber(value: gamma)
        filter.isEnabled = true
    }

    func setEqualizer(presetIndex: Int, preamp: Float) {
        let presets = VLCAudioEqualizer.presets
        guard let preset = presets.first(where: { $0.index == UInt(presetIndex) }) else { return }
        let equalizer = VLCAudioEqualizer(preset: preset)
        equalizer.preAmplification = preamp
        player.equalizer = equalizer
    }

    // MARK: - Frame level

    func stepFrame(forward: Bool) {
        if forward {
            player.gotoNextFrame()
        } else {
            player.gotoPreviousFrame()
        }
    }

    func snapshot() -> UIImage? {
        let name = "pearl-snapshot-\(Int(Date().timeIntervalSince1970)).png"
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(name).path
        player.saveVideoSnapshot(at: path, withWidth: Int32(videoSize.width), andHeight: Int32(videoSize.height))
        // The snapshot is written asynchronously; the delegate callback posts the
        // file once it lands, and the library screen picks it up from there.
        return player.lastSnapshot
    }

    func startRecording() -> URL? {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("pearl-\(Int(Date().timeIntervalSince1970)).ts")
        player.startRecording(atPath: url.path)
        return url
    }

    func stopRecording() {
        player.stopRecording()
    }

    // MARK: - Chapters, titles, programs

    func chapters() -> [String] {
        guard player.numberOfTitles > 0 else { return [] }
        return player.chapterDescriptions(ofTitle: Int32(player.currentTitleIndex)).map { $0.name ?? "Chapter" }
    }

    func selectChapter(index: Int) {
        player.currentChapterIndex = Int32(index)
    }

    func titles() -> [String] {
        player.titleDescriptions.map { $0.name ?? "Title" }
    }

    func selectTitle(index: Int) {
        player.currentTitleIndex = Int32(index)
    }

    // MARK: - A-B loop

    func setABLoop(from: TimeInterval?, to: TimeInterval?) {
        guard let from, let to else {
            _ = player.resetABLoop()
            return
        }
        // The ObjC selector is setABLoopFromTime:toTime:, which Swift imports as
        // setABLoopFrom(_:to:). It is not setABLoop(from:to:).
        _ = player.setABLoopFrom(
            VLCTime(int: Int32(from * 1000)),
            to: VLCTime(int: Int32(to * 1000))
        )
    }

    // MARK: - Network

    func addHTTPHeader(_ name: String, value: String) {
        extraHeaders[name] = value
    }

    func setNetworkCaching(milliseconds: Int) {
        networkCachingMilliseconds = milliseconds
    }

    func setHardwareDecoding(enabled: Bool) {
        hardwareDecodingEnabled = enabled
    }

    func setVolumeGain(_ gain: Float) {
        // libvlc volume is 0 to 100 for normal range, and above that for a boost.
        player.audio?.volume = Int32((min(max(gain, 0), 2) * 100).rounded())
    }

    func setMuted(_ muted: Bool) {
        player.audio?.isMuted = muted
    }

    func setAudioPassthrough(_ enabled: Bool) {
        player.audio?.passthrough = enabled
    }

    // MARK: - Playlist

    func playNext() {
        _ = listPlayer.next
    }

    func playPrevious() {
        _ = listPlayer.previous
    }

    func setRepeat(_ mode: VLCRepeatMode) {
        listPlayer.repeatMode = mode
    }

    // MARK: - Audio session

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetoothA2DP])
            // Activating here matters on a real device: libvlc will sit in
            // "opening" waiting for an audio device that the session never
            // handed it. The simulator is forgiving about this, the phone is
            // not.
            try session.setActive(true)
            RemoteLog.note("audio session active, category playback")
        } catch {
            RemoteLog.note("audio session failed: \(error.localizedDescription)")
        }
    }

    var playerEngineVersion: String {
        "libvlc \(library.version) (\(library.changeset))"
    }

    // MARK: - Event handling, called from the bridge and always on the main actor

    fileprivate func handleStateChanged(_ newState: VLCMediaPlayerState) {
        switch newState {
        case .nothingSpecial:
            setState(.idle)
        case .opening:
            setState(.loading)
        case .playing:
            setState(.playing)
            applyRate(announce: false)
            if let start = pendingStart {
                pendingStart = nil
                seek(to: start)
            }
            refreshTracks()
        case .paused:
            setState(.paused)
            refreshTracks()
        case .stopped:
            setState(.ended)
        case .stopping:
            setState(.idle)
        case .error:
            setState(.failed(VLCLibrary.currentErrorMessage ?? "Playback failed"))
        @unknown default:
            break
        }
    }

    fileprivate func handleTimeChanged() {
        publishTime()
    }

    fileprivate func handleBuffer(_ progress: Float) {
        if state == .loading || state == .playing || state == .paused {
            setState(.buffering(Double(progress)))
        }
        delegate?.engine(self, didUpdateBuffer: Double(progress))
    }

    fileprivate func handleTracksChanged() {
        refreshTracks()
    }

    fileprivate func handleSnapshot(_ path: String?) {
        guard let path, let image = UIImage(contentsOfFile: path) else { return }
        lastSnapshot = image
    }

    private(set) var lastSnapshot: UIImage?

    fileprivate func handleEnded() {
        stopStatsTicker()
        setState(.ended)
        delegate?.engineDidReachEnd(self)
    }

    private func publishTime() {
        // The Picture in Picture controller asks for time and length
        // synchronously from a non-isolated context, so it reads this box rather
        // than hopping onto the main actor.
        pipController.box.update(
            time: Int64(currentTime * 1000),
            length: Int64(duration * 1000),
            playing: isPlaying,
            seekable: isSeekable
        )
        host.refreshPictureInPictureState()
        delegate?.engine(self, didUpdate: currentTime, duration: duration)
    }

    private func setState(_ newState: PlaybackState) {
        guard newState != state else { return }
        state = newState
        RemoteLog.note("state -> \(newState.displayName)")
        delegate?.engine(self, didChange: newState)
    }

    // MARK: - Stats

    private func startStatsTicker() {
        statsTask?.cancel()
        statsTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                self?.refreshStats()
            }
        }
    }

    private func stopStatsTicker() {
        statsTask?.cancel()
        statsTask = nil
    }

    private func refreshStats() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastStatsDate)
        let mediaStats = player.media?.statistics

        var updated = PlaybackStats()
        updated.width = Int(videoSize.width)
        updated.height = Int(videoSize.height)
        if let media = player.media {
            if let videoTrack = media.videoTracks.compactMap({ $0.video }).first {
                updated.width = Int(videoTrack.width)
                updated.height = Int(videoTrack.height)
                if videoTrack.frameRate > 0 {
                    let denominator = max(videoTrack.frameRateDenominator, 1)
                    updated.frameRate = Double(videoTrack.frameRate) / Double(denominator)
                }
            }
            updated.videoCodec = media.videoTracks.first?.codecName()
            updated.audioCodec = media.audioTracks.first?.codecName()
        }
        if let mediaStats {
            updated.videoBitrate = Double(mediaStats.inputBitrate)
            updated.demuxBitrate = Double(mediaStats.demuxBitrate)
            updated.decodedVideo = Int(mediaStats.decodedVideo)
            updated.droppedFrames = Int(mediaStats.latePictures + mediaStats.lostPictures)
            if elapsed > 0 {
                let delta = Double(mediaStats.displayedPictures) - Double(lastDisplayedPictures)
                if delta >= 0 {
                    displayFPS = delta / elapsed
                }
                lastDisplayedPictures = mediaStats.displayedPictures
            }
            updated.displayFPS = displayFPS
        }
        lastStatsDate = now

        stats = updated
        delegate?.engine(self, didUpdateStats: updated)
    }
}

/// A small forwarder so VLCKit's delegate callbacks (which arrive as plain ObjC)
/// never touch main actor state directly.
private final class VLCKitEventBridge: NSObject, VLCMediaPlayerDelegate {
    weak var engine: VLCKitEngine?

    func mediaPlayerStateChanged(_ newState: VLCMediaPlayerState) {
        Task { @MainActor [weak engine] in engine?.handleStateChanged(newState) }
    }

    func mediaPlayerTimeChanged(_ notification: Notification) {
        Task { @MainActor [weak engine] in engine?.handleTimeChanged() }
    }

    func mediaPlayerBufferingChanged(_ progress: Float) {
        Task { @MainActor [weak engine] in engine?.handleBuffer(progress) }
    }

    func mediaPlayerTrackAdded(_ trackId: String) {
        Task { @MainActor [weak engine] in engine?.handleTracksChanged() }
    }

    func mediaPlayerTrackRemoved(_ trackId: String) {
        Task { @MainActor [weak engine] in engine?.handleTracksChanged() }
    }

    func mediaPlayerTrackUpdated(_ trackId: String) {
        Task { @MainActor [weak engine] in engine?.handleTracksChanged() }
    }

    func mediaPlayerTrackSelected(_ trackType: VLCMedia.TrackType) {
        Task { @MainActor [weak engine] in engine?.handleTracksChanged() }
    }

    func mediaPlayerLengthChanged(_ length: Int64) {
        Task { @MainActor [weak engine] in engine?.handleTimeChanged() }
    }

    func mediaPlayerTitleSelectionChanged(_ notification: Notification) {
        Task { @MainActor [weak engine] in engine?.handleTracksChanged() }
    }

    func mediaPlayerTitleListChanged(_ notification: Notification) {
        Task { @MainActor [weak engine] in engine?.handleTracksChanged() }
    }

    func mediaPlayerChapterChanged(_ notification: Notification) {
        Task { @MainActor [weak engine] in engine?.handleTracksChanged() }
    }

    func mediaPlayerProgramListChanged(_ notification: Notification) {
        Task { @MainActor [weak engine] in engine?.handleTracksChanged() }
    }

    func mediaPlayerProgramSelectionChanged(_ notification: Notification) {
        Task { @MainActor [weak engine] in engine?.handleTracksChanged() }
    }

    func mediaPlayerSnapshot(_ notification: Notification) {
        let path = notification.userInfo?["VLCMediaPlayerSnapshotPath"] as? String
        Task { @MainActor [weak engine] in engine?.handleSnapshot(path) }
    }

    func mediaPlayerStartedRecording(_ player: VLCMediaPlayer) {}

    func mediaPlayer(_ player: VLCMediaPlayer, recordingStoppedAt url: URL?) {}

    func mediaPlayer(_ player: VLCMediaPlayer, nextFrameSteppedWith result: VLCMediaPlayerFrameStepResult) {}

    func mediaPlayer(_ player: VLCMediaPlayer, previousFrameSteppedWith result: VLCMediaPlayerFrameStepResult) {}
}
