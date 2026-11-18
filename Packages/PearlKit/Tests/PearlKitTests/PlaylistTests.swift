import Foundation
import Testing

@testable import PearlKit

@Suite("Playlist and HLS parsing")
struct PlaylistTests {
    @Test("m3u entries carry duration and title")
    func m3uEntries() {
        let text = """
            #EXTM3U
            #EXTINF:-1 tvg-id="one",Channel One
            https://cdn.example.com/one.m3u8
            #EXTINF:5400,Movie Two
            https://cdn.example.com/two.mkv
            """
        let entries = PlaylistParser.parse(text)
        #expect(entries.count == 2)
        #expect(entries[0].title == "Channel One")
        #expect(entries[0].duration == nil, "a duration of -1 means live, not zero")
        #expect(entries[1].title == "Movie Two")
        #expect(entries[1].duration == 5400)
    }

    @Test("Relative entries resolve against the playlist location")
    func relativeEntries() {
        let base = URL(string: "https://cdn.example.com/shows/list.m3u")!
        let entries = PlaylistParser.parse("#EXTM3U\n../ep1.mkv\n", baseURL: base)
        #expect(entries.first?.url.absoluteString == "https://cdn.example.com/ep1.mkv")
    }

    @Test("Blank lines and unknown tags are ignored")
    func noise() {
        let text = "#EXTM3U\n\n#EXTVLCOPT:network-caching=1000\nhttps://cdn.example.com/a.mp4\n\n"
        #expect(PlaylistParser.parse(text).count == 1)
    }

    @Test("A master playlist lists its variants best first")
    func hlsVariants() {
        let master = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720,FRAME-RATE=60.000
            low/index.m3u8
            #EXT-X-STREAM-INF:BANDWIDTH=8000000,RESOLUTION=1920x1080,FRAME-RATE=23.976,CODECS="avc1.640028"
            high/index.m3u8
            #EXT-X-STREAM-INF:BANDWIDTH=400000,CODECS="mp4a.40.2"
            audio/index.m3u8
            """
        let base = URL(string: "https://cdn.example.com/movie/master.m3u8")!
        let variants = HLSMasterPlaylist.variants(in: master, baseURL: base)
        #expect(variants.count == 3)
        #expect(variants[0].url.absoluteString == "https://cdn.example.com/movie/high/index.m3u8")
        #expect(variants[0].label == "1080p")
        #expect(variants[1].label == "720p60")
        #expect(variants[2].isAudioOnly)
        #expect(variants[2].label == "Audio only")
    }

    @Test("Trick play tracks are not offered as quality")
    func skipsIFrameOnly() {
        let master = """
            #EXTM3U
            #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=900000,URI="iframe.m3u8"
            #EXT-X-STREAM-INF:BANDWIDTH=3000000,RESOLUTION=1920x1080
            main.m3u8
            """
        let base = URL(string: "https://cdn.example.com/movie/master.m3u8")!
        let variants = HLSMasterPlaylist.variants(in: master, baseURL: base)
        #expect(variants.count == 1)
        #expect(variants.first?.url.absoluteString == "https://cdn.example.com/movie/main.m3u8")
    }

    @Test("A media playlist has no quality to pick")
    func mediaPlaylist() {
        let media = "#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6.0,\nseg1.ts\n"
        #expect(HLSMasterPlaylist.variants(in: media, baseURL: nil).isEmpty)
        #expect(HLSMasterPlaylist.isPlaylist(media))
        #expect(!HLSMasterPlaylist.isPlaylist("<html>"))
    }

    @Test("Bandwidth reads as a bitrate label")
    func bandwidthLabel() {
        let variant = HLSMasterPlaylist.Variant(bandwidth: 8_400_000, url: URL(string: "https://x/y.m3u8")!)
        #expect(variant.bandwidthLabel == "8.4 Mbps")
        #expect(
            HLSMasterPlaylist.Variant(bandwidth: 400_000, url: URL(string: "https://x/y")!).bandwidthLabel == "400 kbps"
        )
    }
}
