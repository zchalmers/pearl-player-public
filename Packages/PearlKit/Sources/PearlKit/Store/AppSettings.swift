import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    public var gestures: GestureSettings
    public var playback: PlaybackSettings
    public var tracks: TrackSettings
    public var appearance: AppearanceSettings
    public var sources: SourceSettings
    public var storage: StorageSettings
    public var diagnostics: DiagnosticSettings
    public var advanced: AdvancedSettings

    public init(
        gestures: GestureSettings = .default,
        playback: PlaybackSettings = .init(),
        tracks: TrackSettings = .init(),
        appearance: AppearanceSettings = .init(),
        sources: SourceSettings = .init(),
        storage: StorageSettings = .init(),
        diagnostics: DiagnosticSettings = .init(),
        advanced: AdvancedSettings = .init()
    ) {
        self.gestures = gestures
        self.playback = playback
        self.tracks = tracks
        self.appearance = appearance
        self.sources = sources
        self.storage = storage
        self.diagnostics = diagnostics
        self.advanced = advanced
    }

    public static let `default` = AppSettings()

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        gestures = try values.decodeIfPresent(GestureSettings.self, forKey: .gestures) ?? .default
        playback = try values.decodeIfPresent(PlaybackSettings.self, forKey: .playback) ?? .init()
        tracks = try values.decodeIfPresent(TrackSettings.self, forKey: .tracks) ?? .init()
        appearance = try values.decodeIfPresent(AppearanceSettings.self, forKey: .appearance) ?? .init()
        sources = try values.decodeIfPresent(SourceSettings.self, forKey: .sources) ?? .init()
        storage = try values.decodeIfPresent(StorageSettings.self, forKey: .storage) ?? .init()
        diagnostics = try values.decodeIfPresent(DiagnosticSettings.self, forKey: .diagnostics) ?? .init()
        advanced = try values.decodeIfPresent(AdvancedSettings.self, forKey: .advanced) ?? .init()
    }
}

public struct PlaybackSettings: Codable, Equatable, Sendable {
    public var hardwareDecoding = true
    public var audioPassThrough = false
    public var backgroundAudio = true
    public var pictureInPicture = true
    public var autoplayNext = true
    public var continuePrompt = true
    public var rememberSpeed = true
    public var pitchCorrection = true
    public var preferredSpeed = 1.0
    public var repeatMode = "off"
    public var shuffle = false
    public var keepAwake = true
    public var preciseSeeking = true

    public init() {}
}

public struct TrackSettings: Codable, Equatable, Sendable {
    public var preferredAudioLanguages: [String] = []
    public var preferredSubtitleLanguages: [String] = []
    public var forcedSubtitles = true
    public var autoLoadSidecars = true
    public var subtitleProviderKey = ""
    public var volumeBoost = 100
    public var normalizeAudio = false
    public var monoAudio = false
    public var spatialAudio = true
    public var equalizerPreset = "Flat"
    public var subtitlePresetID: UUID?

    public init() {}
}

public struct AppearanceSettings: Codable, Equatable, Sendable {
    public var libraryLayout = "grid"
    public var tint = "pearl"
    public var showClock = true
    public var showBattery = true
    public var showThumbnails = true
    public var reducedMotion = false
    public var defaultAspectRatio = "fit"

    public init() {}
}

public struct SourceSettings: Codable, Equatable, Sendable {
    public var userAgent = ""
    public var referer = ""
    public var httpHeaders: [String: String] = [:]
    public var networkCacheMilliseconds = 1_500
    public var clipboardDetection = true
    public var wifiTransferEnabled = false

    public init() {}
}

public struct StorageSettings: Codable, Equatable, Sendable {
    public var downloadOnWiFiOnly = true
    public var keepFinishedDownloads = true
    public var historyLimit = 200
    public var thumbnailCacheMegabytes = 250
    public var autoDeleteWatched = false

    public init() {}
}

public struct DiagnosticSettings: Codable, Equatable, Sendable {
    public var loggingEnabled = true
    public var logLevel = "info"
    public var showPlaybackStats = false

    public init() {}
}

public struct AdvancedSettings: Codable, Equatable, Sendable {
    public var deinterlace = "auto"
    public var toneMapping = "auto"
    public var rendererDiscovery = true
    public var allowCellularStreaming = true
    public var customVLCOptions: [String] = []

    public init() {}
}
