import PearlKit
import SwiftUI
import UIKit

/// The player's state machine. Owns the engine, holds the numbers the controls
/// draw, and turns gestures into engine calls. No VLCKit type appears here.
@MainActor
@Observable
final class PlayerViewModel {
    private(set) var engine: (any PlayerEngine)?
    private(set) var state: PlaybackState = .idle
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var bufferProgress: Double = 0
    private(set) var tracks: [TrackInfo] = []
    private(set) var stats: PlaybackStats = .empty
    private(set) var request: PlayRequest?

    /// Controls overlay visibility and its auto-hide timer.
    var controlsVisible = true
    private(set) var isScrubbing = false
    private(set) var scrubTarget: TimeInterval = 0

    /// Hold to fast forward state: the speed badge shows while this is non-nil.
    private(set) var holdRate: Float?
    private(set) var holdStartTime: TimeInterval = 0

    /// Gesture HUDs.
    var seekHint: SeekHint?
    var volumeHint: Float?
    var brightnessHint: Float?

    var playbackRate: Float = 1 {
        didSet { engine?.rate = playbackRate }
    }
    var aspectRatio: AspectRatioMode = .fit {
        didSet { engine?.setAspectRatio(aspectRatio) }
    }
    var subtitleDelay: TimeInterval = 0 {
        didSet { engine?.setSubtitleDelay(subtitleDelay) }
    }
    var audioDelay: TimeInterval = 0 {
        didSet { engine?.setAudioDelay(audioDelay) }
    }
    var statsOverlayVisible = false

    /// Gesture settings, wired to the settings store later.
    var gestureSettings = GestureSettings.default
    /// Called when the user asks to leave the player. The app decides what that
    /// means (pop the view, or report progress back to Stremio first).
    var onExit: ((PlayRequest?, TimeInterval) -> Void)?

    /// Picture in Picture plumbing and the engine view it needs.
    private var zoomScale: Float = 1

    struct SeekHint: Equatable {
        var text: String
        var target: TimeInterval
        var side: SeekMath.TapZone
    }

    // MARK: - Lifecycle

    func attach(engine: any PlayerEngine) {
        self.engine = engine
        engine.delegate = self
    }

    func load(_ request: PlayRequest) {
        self.request = request
        currentTime = request.startAt ?? 0
        duration = 0
        engine?.load(request)
    }

    func load(url: URL, title: String? = nil) {
        load(PlayRequest(url: url, origin: .manual, title: title))
    }

    // MARK: - Transport

    func togglePlayPause() {
        engine?.togglePlayPause()
        showControls()
    }

    func play() { engine?.play() }
    func pause() { engine?.pause() }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
    }

    func setTemporaryRate(_ rate: Float?) {
        engine?.setTemporaryRate(rate)
        holdRate = rate
    }

    func exit() {
        onExit?(request, currentTime)
    }

    // MARK: - Seeking

    func beginScrub() {
        isScrubbing = true
        scrubTarget = currentTime
        showControls(autoHide: false)
    }

    func updateScrub(to time: TimeInterval) {
        scrubTarget = SeekMath.clampSeek(time, duration: duration)
    }

    func commitScrub() {
        engine?.seek(to: scrubTarget)
        isScrubbing = false
        showControls()
    }

    func seek(to time: TimeInterval) {
        engine?.seek(to: time)
    }

    func seek(by offset: TimeInterval, side: SeekMath.TapZone = .forward) {
        let target = SeekMath.clampSeek(currentTime + offset, duration: duration)
        engine?.seek(to: target)
        seekHint = SeekHint(text: Format.seekDelta(offset), target: target, side: side)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            self?.seekHint = nil
        }
    }

    /// Double tap on the left or right third.
    func doubleTap(zone: SeekMath.TapZone) {
        guard zone != .center else {
            togglePlayPause()
            return
        }
        let seconds = gestureSettings.doubleTapSeconds
        seek(by: zone == .forward ? seconds : -seconds, side: zone)
    }

    // MARK: - Hold to fast forward

    func beginHold() {
        holdStartTime = currentTime
        setTemporaryRate(gestureSettings.holdBaseSpeed)
        showControls(autoHide: false)
    }

    func updateHold(verticalOffset: CGFloat) {
        let speed = SeekMath.holdSpeed(
            verticalOffset: verticalOffset,
            base: gestureSettings.holdBaseSpeed,
            maximum: gestureSettings.holdMaxSpeed
        )
        setTemporaryRate(speed)
    }

    func endHold() {
        let elapsed = currentTime - holdStartTime
        setTemporaryRate(nil)
        if abs(elapsed) > 1 {
            // The engine already moved playback during the hold; this keeps the
            // UI honest if the engine was paused when the gesture started.
            seekHint = SeekHint(
                text: Format.seekDelta(elapsed),
                target: currentTime,
                side: .forward
            )
        }
        showControls()
    }

    /// Fast forward or reverse driven by a long press, rather than by rate.
    func holdSeek(elapsed: TimeInterval, speed: Float) {
        let target = SeekMath.holdTarget(
            time: holdStartTime,
            elapsed: elapsed,
            speed: speed,
            duration: duration
        )
        engine?.seek(to: target)
        holdRate = speed
        seekHint = SeekHint(
            text: Format.seekDelta(target - holdStartTime),
            target: target,
            side: .forward
        )
    }

    // MARK: - Vertical gestures

    func adjustVolume(by delta: Float) {
        let current = volumeHint ?? 1
        let next = min(max(current + delta, 0), 2)
        volumeHint = next
        applyVolume(next)
        scheduleHintClear { self.volumeHint = nil }
    }

    private func applyVolume(_ value: Float) {
        engine?.setVolumeGain(value)
    }

    func adjustBrightness(by delta: Float) {
        let screen = UIScreen.main
        let next = min(max(screen.brightness + CGFloat(delta), 0), 1)
        screen.brightness = next
        brightnessHint = Float(next)
        scheduleHintClear { self.brightnessHint = nil }
    }

    private func scheduleHintClear(_ clear: @escaping @MainActor () -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(800))
            clear()
        }
    }

    // MARK: - Controls visibility

    func toggleControls() {
        if controlsVisible {
            controlsVisible = false
        } else {
            showControls()
        }
    }

    func showControls(autoHide: Bool = true) {
        controlsVisible = true
        guard autoHide, let delay = SeekMath.resolvedAutoHideDelay(gestureSettings.autoHideSeconds) else { return }
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.controlsVisible = false
        }
    }

    private var hideTask: Task<Void, Never>?

    // MARK: - Tracks

    func selectAudio(id: String) {
        engine?.selectAudioTrack(id: id)
    }

    func toggleSubtitle(id: String) {
        let selected = tracks.filter { $0.kind == .subtitle && $0.isSelected }.map(\.id)
        var next = selected
        if let index = next.firstIndex(of: id) {
            next.remove(at: index)
        } else {
            next.append(id)
        }
        engine?.selectSubtitleTracks(ids: next)
    }

    func disableSubtitles() {
        engine?.disableSubtitles()
    }

    func loadSubtitle(url: URL) {
        engine?.addSubtitleFile(url: url, title: url.lastPathComponent)
    }

    var subtitleTracks: [TrackInfo] { tracks.filter { $0.kind == .subtitle } }
    var audioTracks: [TrackInfo] { tracks.filter { $0.kind == .audio } }

    var selectedSubtitleTracks: [TrackInfo] { subtitleTracks.filter(\.isSelected) }
}

extension PlayerViewModel: PlayerEngineDelegate {
    func engine(_ engine: any PlayerEngine, didChange state: PlaybackState) {
        self.state = state
        if state == .playing {
            showControls()
        }
        if case .failed = state {
            controlsVisible = true
        }
    }

    func engine(_ engine: any PlayerEngine, didUpdate time: TimeInterval, duration: TimeInterval) {
        guard !isScrubbing else { return }
        self.currentTime = time
        if duration > 0 { self.duration = duration }
    }

    func engine(_ engine: any PlayerEngine, didUpdateBuffer progress: Double) {
        bufferProgress = progress
    }

    func engine(_ engine: any PlayerEngine, didUpdateTracks tracks: [TrackInfo]) {
        self.tracks = tracks
    }

    func engineDidReachEnd(_ engine: any PlayerEngine) {
        controlsVisible = true
    }

    func engine(_ engine: any PlayerEngine, didUpdateStats stats: PlaybackStats) {
        self.stats = stats
    }

    var engineVersion: String {
        (engine as? VLCKitEngine)?.playerEngineVersion ?? "Pearl Player"
    }

    func togglePictureInPicture() {
        guard let engine else { return }
        if engine.isPictureInPictureActive {
            engine.stopPictureInPicture()
        } else {
            engine.startPictureInPicture()
        }
    }

    func setZoom(scale: CGFloat) {
        zoomScale = min(max(zoomScale * Float(scale), 1), 4)
        engine?.setScaleFactor(zoomScale)
    }

    func resetZoom() {
        zoomScale = 1
        engine?.setScaleFactor(1)
    }

    func toggleLock() {
        gestureSettings.lockControls.toggle()
        if gestureSettings.lockControls {
            controlsVisible = false
        }
    }
}
