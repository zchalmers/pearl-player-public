import PearlKit
import UIKit

/// What the UI needs to hear about from the engine. One protocol, so the UI
/// never imports VLCKit.
@MainActor
public protocol PlayerEngineDelegate: AnyObject {
    func engine(_ engine: any PlayerEngine, didChange state: PlaybackState)
    func engine(_ engine: any PlayerEngine, didUpdate time: TimeInterval, duration: TimeInterval)
    func engine(_ engine: any PlayerEngine, didUpdateBuffer progress: Double)
    func engine(_ engine: any PlayerEngine, didUpdateTracks tracks: [TrackInfo])
    func engineDidReachEnd(_ engine: any PlayerEngine)
    func engine(_ engine: any PlayerEngine, didUpdateStats stats: PlaybackStats)
}

/// The playback engine. VLCKit implements it today, and the UI would not notice
/// a different implementation tomorrow. Main actor bound on purpose: it owns a
/// view and drives UI state.
@MainActor
public protocol PlayerEngine: AnyObject {
    var delegate: (any PlayerEngineDelegate)? { get set }
    /// The view the engine renders into. Hand it to SwiftUI and never replace it.
    var renderView: UIView { get }

    var state: PlaybackState { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var isPlaying: Bool { get }
    var isSeekable: Bool { get }
    var videoSize: CGSize { get }
    var stats: PlaybackStats { get }
    var tracks: [TrackInfo] { get }
    var currentRequest: PlayRequest? { get }

    /// Picture in Picture, driven through the engine so no VLCKit type has to
    /// leak into the UI layer.
    var isPictureInPictureAvailable: Bool { get }
    var isPictureInPictureActive: Bool { get }
    func startPictureInPicture()
    func stopPictureInPicture()

    /// Normal playback rate. 1.0 unless the user changed playback speed.
    var rate: Float { get set }

    func load(_ request: PlayRequest)
    func play()
    func pause()
    func togglePlayPause()
    func stop()
    func seek(to time: TimeInterval)
    func seek(by offset: TimeInterval)

    /// Temporary speed used while a hold-to-fast-forward gesture is active.
    /// Passing nil restores the normal rate.
    func setTemporaryRate(_ rate: Float?)

    func selectAudioTrack(id: String)
    func selectSubtitleTracks(ids: [String])
    func disableSubtitles()
    func addSubtitleFile(url: URL, title: String?)
    func setSubtitleDelay(_ seconds: TimeInterval)
    func setAudioDelay(_ seconds: TimeInterval)

    func setAspectRatio(_ mode: AspectRatioMode)
    func setScaleFactor(_ factor: Float)
    func setDeinterlace(_ enabled: Bool)
    func setVideoAdjustment(brightness: Float, contrast: Float, saturation: Float, hue: Float, gamma: Float)
    func setEqualizer(presetIndex: Int, preamp: Float)

    func stepFrame(forward: Bool)
    func snapshot() -> UIImage?
    func startRecording() -> URL?
    func stopRecording()

    func setABLoop(from: TimeInterval?, to: TimeInterval?)
    func chapters() -> [String]
    func selectChapter(index: Int)
    func titles() -> [String]
    func selectTitle(index: Int)

    func addHTTPHeader(_ name: String, value: String)
    func setNetworkCaching(milliseconds: Int)
    func setHardwareDecoding(enabled: Bool)

    /// 1.0 is normal, up to roughly 2.0 for a boost.
    func setVolumeGain(_ gain: Float)
    func setMuted(_ muted: Bool)
    func setAudioPassthrough(_ enabled: Bool)
}

extension PlayerEngine {
    public func togglePlayPause() {
        isPlaying ? pause() : play()
    }
}
