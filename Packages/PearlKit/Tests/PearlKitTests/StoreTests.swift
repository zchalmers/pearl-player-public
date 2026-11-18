import Foundation
import Testing

@testable import PearlKit

@Suite("JSON settings and library stores")
struct StoreTests {
    @Test("Settings round trip every section")
    func settingsRoundTrip() throws {
        var settings = AppSettings.default
        settings.gestures.doubleTapSeconds = 30
        settings.playback.preferredSpeed = 1.5
        settings.tracks.preferredAudioLanguages = ["eng", "jpn"]
        settings.appearance.libraryLayout = "list"
        settings.sources.userAgent = "Pearl"
        settings.storage.historyLimit = 42
        settings.diagnostics.showPlaybackStats = true
        settings.advanced.deinterlace = "on"

        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(AppSettings.self, from: data) == settings)
    }

    @Test("An older settings document gains defaults for new sections")
    func settingsMigration() throws {
        var oldSettings = AppSettings.default
        oldSettings.playback.hardwareDecoding = false
        let complete = try JSONSerialization.jsonObject(with: JSONEncoder().encode(oldSettings))
        var object = try #require(complete as? [String: Any])
        object.removeValue(forKey: "gestures")
        object.removeValue(forKey: "storage")
        let data = try JSONSerialization.data(withJSONObject: object)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)
        #expect(!settings.playback.hardwareDecoding)
        #expect(settings.gestures == .default)
        #expect(settings.storage == StorageSettings())
    }

    @Test("Missing and corrupt files safely use defaults")
    func storeFallback() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let url = directory.appending(path: "settings.json")
        let store = JSONFileStore(url: url, fallback: AppSettings.default)
        #expect(store.load() == .default)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        #expect(store.load() == .default)
    }

    @Test("Atomic file store saves and updates")
    func storeUpdate() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "library.json")
        let store = JSONFileStore(url: url, fallback: LibraryState())
        let media = URL(string: "https://example.com/movie.mkv")!
        try store.update { $0.record(url: media, position: 25, duration: 100) }
        #expect(store.load().resume[media.absoluteString]?.position == 25)
    }

    @Test("Resume, watched, recents and history update together")
    func playbackRecord() {
        let media = URL(fileURLWithPath: "/tmp/Movie.mkv")
        var state = LibraryState()
        state.record(url: media, title: "Movie", position: 95, duration: 100, historyLimit: 1)
        state.record(url: media, title: "Movie", position: 96, duration: 100, historyLimit: 1)
        let key = LibraryState.key(for: media)
        #expect(state.watched.contains(key))
        #expect(state.resume[key]?.progress == 0.96)
        #expect(state.recents == [media])
        #expect(state.history.count == 1)
    }

    @Test("Playlists create, rename, reorder and delete")
    func playlistMutations() {
        var state = LibraryState()
        let first = state.createPlaylist(named: "First")
        _ = state.createPlaylist(named: "Second")
        state.renamePlaylist(id: first, to: "Renamed")
        state.movePlaylists(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        #expect(state.playlists.map(\.name) == ["Second", "Renamed"])
        state.deletePlaylists(atOffsets: IndexSet(integer: 0))
        #expect(state.playlists.map(\.name) == ["Renamed"])
    }

    @Test("Network source URLs never contain credential material")
    func networkSourceURL() throws {
        let source = NetworkSource(
            name: "NAS", protocolKind: .sftp, host: "nas.local", port: 22, path: "videos", username: "zach")
        #expect(source.url?.absoluteString == "sftp://nas.local:22/videos")
        let json = String(decoding: try JSONEncoder().encode(source), as: UTF8.self)
        #expect(!json.contains("password"))
    }
}
