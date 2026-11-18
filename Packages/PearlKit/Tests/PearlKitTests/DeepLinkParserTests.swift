import Foundation
import Testing

@testable import PearlKit

@Suite("Deep link parsing")
struct DeepLinkParserTests {
    @Test("Stremio's Outplayer handoff is a scheme swapped URL, not encoded")
    func outplayerPlain() {
        let outcome = DeepLinkParser.parse("outplayer://https://cdn.example.com/movie.mkv")
        let request = try? #require(outcome.playRequest)
        #expect(request?.url.absoluteString == "https://cdn.example.com/movie.mkv")
        #expect(request?.origin == .stremio)
    }

    /// What iOS actually delivers. LaunchServices eats the colon of the inner
    /// scheme, so the app is handed `outplayer://https//host/x.mkv`. That was
    /// silently turned into "not a stream" and every Stremio handoff died there.
    @Test("The handoff iOS actually delivers, with the inner colon stripped")
    func outplayerStrippedColon() {
        let outcome = DeepLinkParser.parse("outplayer://https//cdn.example.com/movie.mkv")
        let request = try? #require(outcome.playRequest)
        #expect(request?.url.absoluteString == "https://cdn.example.com/movie.mkv")
    }

    @Test("A stripped colon survives the whole torrentio shape")
    func outplayerStrippedColonLong() {
        let inner =
            "https//torrentio.strem.fun/resolve/realdebrid/ABC/def/null/1/"
            + "Below.1x02.Garden.Party.1080p.NFRip.AAC.x265-Pir8.mkv"
        let outcome = DeepLinkParser.parse("outplayer://" + inner)
        #expect(outcome.playRequest?.url.scheme == "https")
        #expect(outcome.playRequest?.url.pathExtension == "mkv")
    }

    @Test("Stremio's Outplayer handoff also arrives percent encoded")
    func outplayerEncoded() {
        let encoded = "outplayer%3A%2F%2Fhttps%3A%2F%2Fcdn.example.com%2Fa%2520movie.mkv"
        let outcome = DeepLinkParser.parse("pearl://\(encoded)")
        let request = try? #require(outcome.playRequest)
        #expect(request?.url.absoluteString == "https://cdn.example.com/a%20movie.mkv")
    }

    @Test("A handoff keeps the stream's own query string")
    func outplayerWithQuery() {
        let outcome = DeepLinkParser.parse("outplayer://https://cdn.example.com/movie.mkv?token=abc&exp=1")
        let request = try? #require(outcome.playRequest)
        #expect(request?.url.query?.contains("token=abc") == true)
    }

    @Test("Stremio's VLC handoff is an x-callback-url with a url parameter")
    func vlcCallback() {
        let link = "vlc-x-callback://x-callback-url/stream?url=https%3A%2F%2Fcdn.example.com%2Fshow.mkv"
        let outcome = DeepLinkParser.parse(link)
        let request = try? #require(outcome.playRequest)
        #expect(request?.url.absoluteString == "https://cdn.example.com/show.mkv")
    }

    @Test("The Infuse shaped handoff carries a callback and a start position")
    func infuseShape() {
        let link =
            "pearl://x-callback-url/play"
            + "?url=https%3A%2F%2Fcdn.example.com%2Fep1.mkv"
            + "&x-success=stremio%3A%2F%2F%2Fdetail%2Fseries%2Ftt123%2Ftt123%3A1%3A1"
            + "&position=412.5"
            + "&filename=Episode%201"
        let outcome = DeepLinkParser.parse(link)
        let request = try? #require(outcome.playRequest)
        #expect(request?.url.absoluteString == "https://cdn.example.com/ep1.mkv")
        #expect(request?.startAt == 412.5)
        #expect(request?.callbackURL?.scheme == "stremio")
        #expect(request?.title == "Episode 1")
    }

    @Test("The short vlc form works too")
    func vlcShort() {
        let outcome = DeepLinkParser.parse("vlc://http://192.0.2.5:8080/stream.ts")
        let request = try? #require(outcome.playRequest)
        #expect(request?.url.absoluteString == "http://192.0.2.5:8080/stream.ts")
    }

    @Test("A plain media URL plays as itself")
    func plainURL() {
        let outcome = DeepLinkParser.parse("https://cdn.example.com/video.mp4")
        #expect(outcome.playRequest?.url.absoluteString == "https://cdn.example.com/video.mp4")
    }

    @Test("A file URL plays as a document")
    func fileURL() {
        let outcome = DeepLinkParser.parse("file:///var/mobile/Downloads/movie.mkv")
        #expect(outcome.playRequest?.url.path == "/var/mobile/Downloads/movie.mkv")
    }

    @Test("Magnet links say what is actually missing")
    func magnet() {
        let outcome = DeepLinkParser.parse("magnet:?xt=urn:btih:abcdef1234567890")
        #expect(outcome == .needsTorrentEngine(raw: "magnet:?xt=urn:btih:abcdef1234567890"))
    }

    @Test("Stremio's M3U selection arrives as a base64 data URI")
    func dataURIPlaylist() {
        let playlist = "#EXTM3U\n#EXTINF:-1,Part two\nhttps://cdn.example.com/part2.mkv\n"
        let base64 = Data(playlist.utf8).base64EncodedString()
        let outcome = DeepLinkParser.parse("data:application/vnd.apple.mpegurl;base64,\(base64)")
        let request = try? #require(outcome.playRequest)
        #expect(request?.playlist?.count == 1)
        #expect(request?.url.absoluteString == "https://cdn.example.com/part2.mkv")
        #expect(request?.playlist?.first?.title == "Part two")
    }

    @Test("Per source HTTP headers survive the trip")
    func headers() {
        let link =
            "pearl://x-callback-url/play?url=https%3A%2F%2Fcdn.example.com%2Fm.mkv"
            + "&headers=User-Agent%3APearl%2F1.0%7CReferer%3Ahttps%3A%2F%2Fstremio.com"
        let outcome = DeepLinkParser.parse(link)
        let request = try? #require(outcome.playRequest)
        #expect(request?.httpHeaders["User-Agent"] == "Pearl/1.0")
        #expect(request?.httpHeaders["Referer"] == "https://stremio.com")
    }

    @Test("Nonsense gets a reason instead of a crash")
    func garbage() {
        #expect(DeepLinkParser.parse("").playRequest == nil)
        #expect(DeepLinkParser.parse("not a url").playRequest == nil)
        #expect(DeepLinkParser.parse("outplayer://").playRequest == nil)
        #expect(DeepLinkParser.parse("outplayer://ftp://").playRequest == nil)
        #expect(DeepLinkParser.parse("mailto:someone@example.com").playRequest == nil)
    }

    @Test("Header field parsing accepts the three separators")
    func headerField() {
        #expect(DeepLinkParser.parseHeaders("A:1|B:2") == ["A": "1", "B": "2"])
        #expect(DeepLinkParser.parseHeaders("A=1&B=2") == ["A": "1", "B": "2"])
        #expect(DeepLinkParser.parseHeaders("A:1;B:2") == ["A": "1", "B": "2"])
        #expect(DeepLinkParser.parseHeaders("broken") == [:])
    }
}
