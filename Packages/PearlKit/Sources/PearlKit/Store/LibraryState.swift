import Foundation

public struct ResumeEntry: Codable, Equatable, Sendable {
    public var position: TimeInterval
    public var duration: TimeInterval?
    public var updatedAt: Date

    public init(position: TimeInterval, duration: TimeInterval? = nil, updatedAt: Date = .now) {
        self.position = position
        self.duration = duration
        self.updatedAt = updatedAt
    }

    public var progress: Double? {
        guard let duration, duration > 0 else { return nil }
        return min(max(position / duration, 0), 1)
    }
}

public struct HistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var url: URL
    public var title: String?
    public var playedAt: Date

    public init(id: UUID = UUID(), url: URL, title: String? = nil, playedAt: Date = .now) {
        self.id = id
        self.url = url
        self.title = title
        self.playedAt = playedAt
    }
}

public struct Playlist: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var items: [URL]

    public init(id: UUID = UUID(), name: String, items: [URL] = []) {
        self.id = id
        self.name = name
        self.items = items
    }
}

public struct Bookmark: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var mediaURL: URL
    public var time: TimeInterval
    public var title: String

    public init(id: UUID = UUID(), mediaURL: URL, time: TimeInterval, title: String) {
        self.id = id
        self.mediaURL = mediaURL
        self.time = time
        self.title = title
    }
}

public struct SubtitleStylePreset: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var fontName: String
    public var size: Double
    public var bold: Bool
    public var italic: Bool
    public var textColor: String
    public var outlineColor: String
    public var outlineWidth: Double
    public var shadow: Bool
    public var backgroundColor: String
    public var backgroundOpacity: Double
    public var verticalPosition: Double
    public var overrideEmbeddedStyle: Bool

    public init(id: UUID = UUID(), name: String, fontName: String = "System", size: Double = 24) {
        self.id = id
        self.name = name
        self.fontName = fontName
        self.size = size
        bold = false
        italic = false
        textColor = "#FFFFFF"
        outlineColor = "#000000"
        outlineWidth = 2
        shadow = true
        backgroundColor = "#000000"
        backgroundOpacity = 0
        verticalPosition = 0.9
        overrideEmbeddedStyle = false
    }
}

public struct TrackDelay: Codable, Equatable, Sendable {
    public var subtitle: TimeInterval
    public var audio: TimeInterval

    public init(subtitle: TimeInterval = 0, audio: TimeInterval = 0) {
        self.subtitle = subtitle
        self.audio = audio
    }
}

public struct LibraryState: Codable, Equatable, Sendable {
    public var resume: [String: ResumeEntry] = [:]
    public var watched: Set<String> = []
    public var recents: [URL] = []
    public var favorites: Set<String> = []
    public var playlists: [Playlist] = []
    public var bookmarks: [Bookmark] = []
    public var subtitlePresets: [SubtitleStylePreset] = []
    public var delays: [String: TrackDelay] = [:]
    public var history: [HistoryEntry] = []

    public init() {}

    public static func key(for url: URL) -> String {
        url.isFileURL ? url.standardizedFileURL.path : url.absoluteString
    }

    public mutating func record(
        url: URL,
        title: String? = nil,
        position: TimeInterval,
        duration: TimeInterval? = nil,
        date: Date = .now,
        historyLimit: Int = 200
    ) {
        let key = Self.key(for: url)
        resume[key] = ResumeEntry(position: max(position, 0), duration: duration, updatedAt: date)
        if let duration, duration > 0, position / duration >= 0.9 {
            watched.insert(key)
        }
        recents.removeAll { Self.key(for: $0) == key }
        recents.insert(url, at: 0)
        history.insert(HistoryEntry(url: url, title: title, playedAt: date), at: 0)
        history = Array(history.prefix(max(historyLimit, 0)))
    }

    public mutating func createPlaylist(named name: String) -> UUID {
        let playlist = Playlist(name: name)
        playlists.append(playlist)
        return playlist.id
    }

    public mutating func renamePlaylist(id: UUID, to name: String) {
        guard let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].name = name
    }

    public mutating func movePlaylists(fromOffsets: IndexSet, toOffset: Int) {
        let moving = fromOffsets.sorted().map { playlists[$0] }
        for index in fromOffsets.sorted(by: >) { playlists.remove(at: index) }
        let removedBefore = fromOffsets.filter { $0 < toOffset }.count
        playlists.insert(contentsOf: moving, at: min(max(toOffset - removedBefore, 0), playlists.count))
    }

    public mutating func deletePlaylists(atOffsets offsets: IndexSet) {
        for index in offsets.sorted(by: >) { playlists.remove(at: index) }
    }
}

public enum NetworkProtocol: String, Codable, CaseIterable, Sendable {
    case smb, nfs, ftp, ftps, sftp, webDAV, upnp, dlna
}

public struct NetworkSource: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var protocolKind: NetworkProtocol
    public var host: String
    public var port: Int?
    public var path: String
    public var username: String
    public var credentialID: String

    public init(
        id: UUID = UUID(),
        name: String,
        protocolKind: NetworkProtocol,
        host: String,
        port: Int? = nil,
        path: String = "",
        username: String = "",
        credentialID: String = UUID().uuidString
    ) {
        self.id = id
        self.name = name
        self.protocolKind = protocolKind
        self.host = host
        self.port = port
        self.path = path
        self.username = username
        self.credentialID = credentialID
    }

    public var url: URL? {
        let scheme = protocolKind == .webDAV ? "https" : protocolKind.rawValue.lowercased()
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        components.path = path.hasPrefix("/") ? path : "/" + path
        return components.url
    }
}
