import Foundation
import Testing

@testable import PearlKit

@Suite("Talking back to Stremio")
struct StremioBridgeTests {
    @Test("The progress URL keeps the detail route and adds the position")
    func progressURL() {
        let callback = URL(string: "stremio:///detail/series/tt123/tt123:1:1")!
        let result = StremioBridge.progressURL(callback: callback, position: 412.5)
        let text = try? #require(result?.absoluteString)
        #expect(text?.hasPrefix("stremio://") == true)
        #expect(text?.contains("/detail/series/tt123/tt123:1:1") == true)
        #expect(text?.contains("position=412.500") == true)
    }

    @Test("An existing position is replaced, not duplicated")
    func replacesPosition() {
        let callback = URL(string: "stremio:///detail/movie/tt1/tt1?position=1&foo=bar")!
        let result = StremioBridge.progressURL(callback: callback, position: 60)
        let query = result?.query ?? ""
        #expect(query.components(separatedBy: "position=").count == 2)
        #expect(query.contains("foo=bar"))
        #expect(query.contains("position=60.000"))
    }

    @Test("The played URL rides along when we have it")
    func includesLastPlayed() {
        let callback = URL(string: "stremio:///detail/movie/tt1/tt1")!
        let result = StremioBridge.progressURL(
            callback: callback,
            position: 10,
            lastPlayedURL: URL(string: "https://cdn.example.com/a.mkv"))
        #expect(result?.query?.contains("lastPlayedUrl=") == true)
    }

    @Test("A detail URL can be built from ids")
    func detailURL() {
        let url = StremioBridge.detailURL(type: "series", id: "tt123", videoID: "tt123:2:4", position: 30)
        #expect(url?.absoluteString == "stremio:///detail/series/tt123/tt123:2:4?position=30.000")
        #expect(StremioBridge.detailURL(type: "", id: "x", videoID: nil, position: nil) == nil)
    }

    @Test("Ids come back out of a detail URL")
    func ids() {
        let parsed = StremioBridge.ids(fromDetailURL: URL(string: "stremio:///detail/series/tt123/tt123:1:2")!)
        #expect(parsed?.type == "series")
        #expect(parsed?.id == "tt123")
        #expect(parsed?.videoID == "tt123:1:2")
        #expect(StremioBridge.ids(fromDetailURL: URL(string: "stremio:///settings")!) == nil)
    }

    @Test("The setup userscript covers all three Stremio hosts and both schemes")
    func userScript() {
        let source = StremioUserScript.source
        #expect(source.contains("web.stremio.com"))
        #expect(source.contains("web.strem.io"))
        #expect(source.contains("outplayer"))
        #expect(source.contains("vlc-x-callback"))
        #expect(source.contains("x-success"))
    }
}

@Suite("Play requests")
struct PlayRequestTests {
    @Test("A request carries its origin and debug summary")
    func summary() {
        let request = PlayRequest(
            url: URL(string: "https://cdn.example.com/a.mkv")!,
            origin: .stremio,
            sourceApp: "outplayer")
        #expect(request.debugSummary == "stremio/outplayer https://cdn.example.com/a.mkv")
    }

    @Test("Playlist entries round trip through JSON, for the resume store")
    func codable() throws {
        let entry = PlaylistEntry(duration: 12, title: "One", url: URL(string: "https://x/y.mkv")!)
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(PlaylistEntry.self, from: data)
        #expect(decoded == entry)
    }
}
