import Testing
import UIKit

@testable import PearlKit
@testable import PearlPlayer

@Suite("App level intake")
@MainActor
struct AppIntakeTests {
    /// Models are held for the life of the test process on purpose. Releasing an
    /// AppModel releases its engine, and VLCKit's playback block runs on a worker
    /// queue, so a mid-test release segfaults inside libvlc_media_list_lock.
    private static var retained: [AppModel] = []

    private static func makeModel() -> AppModel {
        let model = AppModel()
        retained.append(model)
        return model
    }

    @Test("A Stremio handoff reaches the player with the stream intact")
    func stremioHandoff() {
        let model = Self.makeModel()
        model.handleIncoming(url: URL(string: "outplayer://https://cdn.example.com/movie.mkv")!)
        #expect(model.player?.request?.url.absoluteString == "https://cdn.example.com/movie.mkv")
        #expect(model.notice == nil)
    }

    @Test("A magnet link explains what is actually missing")
    func magnetNotice() {
        let model = Self.makeModel()
        model.handleIncoming(string: "magnet:?xt=urn:btih:1234567890")
        #expect(model.player == nil)
        #expect(model.notice?.contains("torrent") == true)
    }

    @Test("An unusable link says why instead of failing silently")
    func unsupportedNotice() {
        let model = Self.makeModel()
        model.handleIncoming(string: "mailto:someone@example.com")
        #expect(model.player == nil)
        #expect(model.notice != nil)
    }

    @Test("Recently opened streams are remembered newest first")
    func recents() {
        let model = Self.makeModel()
        model.handleIncoming(string: "https://cdn.example.com/one.mkv")
        model.handleIncoming(string: "https://cdn.example.com/two.mkv")
        #expect(model.recentRequests.first?.url.absoluteString == "https://cdn.example.com/two.mkv")
        #expect(model.recentRequests.count == 2)
    }

    @Test("Shutting the app model down releases the engine cleanly")
    func shutdownIsClean() {
        let model = Self.makeModel()
        model.handleIncoming(string: "https://cdn.example.com/three.mkv")
        #expect(model.player != nil)
        model.shutdown()
        #expect(model.player == nil)
    }
}

@Suite("Playback engine")
@MainActor
struct EngineTests {
    @Test("libvlc boots inside the app and reports its version")
    func engineBoots() {
        let engine = VLCKitEngine()
        #expect(engine.playerEngineVersion.contains("libvlc"))
        #expect(engine.state == .idle)
        #expect(engine.isPictureInPictureAvailable == false)
    }
    @Test("The drawable host puts libvlc's view inside the container it exposes")
    func drawableHost() {
        let host = VLCVideoHost()
        let rendering = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        host.addSubview(rendering)
        #expect(host.view.subviews.count == 1)
        #expect(host.view.subviews.first === rendering)
        #expect(host.bounds() == host.view.bounds)
        // The drawable interface is unannotated, so nil has to be tolerated too.
        host.addSubview(nil)
        #expect(host.view.subviews.count == 1)
    }

    @Test("The engine exposes a plain UIView, which is what the protocol requires")
    func engineViewType() {
        let engine = VLCKitEngine()
        #expect(engine.renderView.backgroundColor == .black)
        #expect(engine.isPictureInPictureActive == false)
    }

    @Test("Two engines in a row do not fight over VLCKit's single library")
    func twoEngines() {
        // This is the path that crashed the test host: open a stream, go back,
        // open another. VLCKit supports one VLCLibrary per process.
        let first = VLCKitEngine()
        first.load(PlayRequest(url: URL(string: "https://cdn.example.com/one.mkv")!))
        let second = VLCKitEngine()
        second.load(PlayRequest(url: URL(string: "https://cdn.example.com/two.mkv")!))
        #expect(first.playerEngineVersion == second.playerEngineVersion)
        first.shutdown()
        second.shutdown()
    }

    @Test("Seeking an empty engine does not trap")
    func emptySeek() {
        let engine = VLCKitEngine()
        engine.seek(to: 100)
        engine.seek(by: -20)
        #expect(engine.duration >= 0)
    }

    @Test("The snapshot box is safe to read from any thread")
    func snapshotBox() {
        let controller = PictureInPictureController()
        controller.box.update(time: 1500, length: 9000, playing: true, seekable: true)
        #expect(controller.mediaTime() == 1500)
        #expect(controller.mediaLength() == 9000)
        #expect(controller.isMediaPlaying())
    }

    /// The regression that shipped a crash to the phone: libvlc raises its state
    /// callbacks on an input thread. `VLCEventsDefaultConfiguration` delivers
    /// those synchronously on that thread, the delegate bridge is main actor
    /// isolated under `SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor`, and the Swift
    /// concurrency runtime killed the process with SIGTRAP the moment the play
    /// tap started the stream. Playing a real stream for ten seconds exercises
    /// the whole callback path, so a regression here fails the run instead of
    /// the phone.
    @Test("A real stream runs its libvlc callbacks without trapping")
    func playsARealStream() async throws {
        let engine = VLCKitEngine()
        let stream = URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8")!
        engine.load(PlayRequest(url: stream, origin: .url))
        #expect(engine.state == .loading)
        try await Task.sleep(for: .seconds(10))
        if case .failed(let reason) = engine.state {
            Issue.record("libvlc could not start the stream: \(reason)")
        }
        engine.shutdown()
    }
}

@Suite("Deep links in the app target")
struct AppDeepLinkTests {
    @Test("The schemes the app claims are the schemes Stremio uses")
    func claimedSchemes() {
        let schemes = DeepLinkParser.handledSchemes
        #expect(schemes.contains("outplayer"))
        #expect(schemes.contains("vlc-x-callback"))
        #expect(schemes.contains("vlc"))
        #expect(schemes.contains("pearl"))
    }

    @Test("Every form Stremio can produce parses")
    func stremioForms() {
        let forms = [
            "outplayer://https://cdn.example.com/a.mkv",
            "vlc-x-callback://x-callback-url/stream?url=https%3A%2F%2Fcdn.example.com%2Fb.mkv",
            "vlc://https://cdn.example.com/c.mkv",
            "pearl://x-callback-url/play?url=https%3A%2F%2Fcdn.example.com%2Fd.mkv"
        ]
        for form in forms {
            #expect(DeepLinkParser.parse(form).playRequest != nil, "failed to parse \(form)")
        }
    }
}
