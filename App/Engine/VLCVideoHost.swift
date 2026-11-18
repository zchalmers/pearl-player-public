import Foundation
import UIKit
import VLCKit

/// The object libvlc renders into, plus the Picture in Picture plumbing.
///
/// This is deliberately NOT a UIView subclass. VLCDrawable declares `bounds()`
/// as a method and, because its header carries no nullability annotations, its
/// requirements import as `addSubview(_ view: UIView?)`, `mediaController()` with
/// an optional return and `pictureInPictureReady()` returning an optional block
/// whose parameter is also optional. A UIView cannot witness a method
/// requirement with a property, and its non-optional `addSubview(_:)` cannot
/// witness an optional parameter, so the drawable has to be a host object that
/// owns a view and forwards into it. The compiler printed those four exact
/// signatures when a memberless type was made to conform, and they are what this
/// type matches.
final class VLCVideoHost: NSObject, VLCDrawable, VLCPictureInPictureDrawable {
    /// The container the app puts on screen. libvlc adds its own rendering
    /// subview into this.
    let view: UIView

    /// Playback controls handed to the Picture in Picture window.
    weak var mediaControllerProvider: (any VLCPictureInPictureMediaControlling)?
    /// Set by the engine so the UI can reflect PiP state.
    var onPictureInPictureStateChange: ((Bool) -> Void)?

    private var windowController: (any VLCPictureInPictureWindowControlling)?
    /// The protocol has no active-state property, so the state the window
    /// reports through `stateChangeEventHandler` is the source of truth.
    private var pipStarted = false

    override init() {
        view = UIView(frame: .zero)
        super.init()
        view.backgroundColor = .black
        // libvlc's subview is not interactive, and neither is the container: the
        // gesture layer sits above it in the view hierarchy.
        view.isUserInteractionEnabled = false
    }

    // MARK: - VLCDrawable

    func addSubview(_ view: UIView?) {
        guard let renderingView = view else { return }
        renderingView.frame = self.view.bounds
        renderingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(renderingView)
    }

    func bounds() -> CGRect {
        view.bounds
    }

    // MARK: - VLCPictureInPictureDrawable

    func mediaController() -> (any VLCPictureInPictureMediaControlling)? {
        mediaControllerProvider ?? InertMediaController()
    }

    func pictureInPictureReady() -> (((any VLCPictureInPictureWindowControlling)?) -> Void)? {
        { [weak self] controller in
            guard let controller else { return }
            self?.windowController = controller
            controller.stateChangeEventHandler = { [weak self] isStarted in
                self?.pipStarted = isStarted
                self?.onPictureInPictureStateChange?(isStarted)
            }
        }
    }

    var isPictureInPictureAvailable: Bool {
        windowController != nil
    }

    var isPictureInPictureActive: Bool {
        pipStarted
    }

    func startPictureInPicture() {
        windowController?.startPictureInPicture()
    }

    func stopPictureInPicture() {
        windowController?.stopPictureInPicture()
    }

    /// Called on every playback state change so the PiP window keeps up.
    func refreshPictureInPictureState() {
        windowController?.invalidatePlaybackState()
    }
}

/// Used before the engine has supplied its own controller, so PiP capabilities
/// can be asked for without crashing.
private final class InertMediaController: NSObject, VLCPictureInPictureMediaControlling {
    func play() {}
    func pause() {}
    func seek(by offset: Int64, completion: @escaping () -> Void) { completion() }
    func mediaLength() -> Int64 { 0 }
    func mediaTime() -> Int64 { 0 }
    func isMediaSeekable() -> Bool { false }
    func isMediaPlaying() -> Bool { false }
}

/// A lock guarded snapshot of the playback state.
///
/// The Picture in Picture protocol asks for time, duration and playing state
/// synchronously from a non-isolated context, so those answers cannot come from
/// main actor state directly. The engine keeps this box up to date on every time
/// tick, and the controller reads it without an isolation hop.
final class PlaybackSnapshotBox: @unchecked Sendable {
    struct Snapshot {
        var time: Int64
        var length: Int64
        var playing: Bool
        var seekable: Bool
    }

    private let lock = NSLock()
    private var stored = Snapshot(time: 0, length: 0, playing: false, seekable: false)

    func update(time: Int64, length: Int64, playing: Bool, seekable: Bool) {
        lock.lock()
        stored = Snapshot(time: time, length: length, playing: playing, seekable: seekable)
        lock.unlock()
    }

    var snapshot: Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

/// Picture in Picture controls, wired to the engine.
final class PictureInPictureController: NSObject, VLCPictureInPictureMediaControlling {
    weak var engine: (any PlayerEngine)?
    let box = PlaybackSnapshotBox()

    func play() {
        Task { @MainActor [weak engine] in engine?.play() }
    }

    func pause() {
        Task { @MainActor [weak engine] in engine?.pause() }
    }

    func seek(by offset: Int64, completion: @escaping () -> Void) {
        Task { @MainActor [weak engine] in
            engine?.seek(by: TimeInterval(offset) / 1000)
            completion()
        }
    }

    func mediaLength() -> Int64 { box.snapshot.length }

    func mediaTime() -> Int64 { box.snapshot.time }

    func isMediaSeekable() -> Bool { box.snapshot.seekable }

    func isMediaPlaying() -> Bool { box.snapshot.playing }
}
