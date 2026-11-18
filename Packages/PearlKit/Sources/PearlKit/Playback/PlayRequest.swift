import Foundation

/// A single thing the player was asked to play, however it arrived.
///
/// Pearl is fed URLs by four routes: Stremio's external player handoff, the
/// system "Open in" sheet, a clipboard paste, or the in-app URL field. They all
/// normalise to this type so nothing downstream has to care where it came from.
public struct PlayRequest: Equatable, Sendable {
    /// Where the request came from. Kept so the UI can offer the right
    /// follow-up action (for example, syncing progress back to Stremio only
    /// makes sense for a Stremio handoff).
    public enum Origin: String, Codable, Sendable {
        /// Handed over by Stremio (dropdown handoff or the userscript).
        case stremio
        /// Any other application opening us through a URL scheme or a document.
        case externalApp
        /// A file picked in Files or shared to us.
        case document
        /// A link found on the clipboard at launch.
        case clipboard
        /// Typed or pasted into the in-app URL field.
        case manual
        /// A plain URL with no other context.
        case url
    }

    /// The stream itself.
    public var url: URL
    /// Which route it came in on.
    public var origin: Origin
    /// Title to show in the player, when the handoff carried one.
    public var title: String?
    /// Seconds to start at, from a resume parameter on the handoff.
    public var startAt: TimeInterval?
    /// Extra HTTP headers for this source only. Debrid and some IPTV sources
    /// need a User-Agent or Referer, so this is per request rather than global.
    public var httpHeaders: [String: String]
    /// Set when the handoff was a playlist rather than a single stream.
    public var playlist: [PlaylistEntry]?
    /// The app or scheme that handed the request over, for the diagnostics view.
    public var sourceApp: String?
    /// The Stremio detail URL to return to with a playback position, when the
    /// handoff carried one (`x-success`). See `StremioBridge`.
    public var callbackURL: URL?

    public init(
        url: URL,
        origin: Origin = .url,
        title: String? = nil,
        startAt: TimeInterval? = nil,
        httpHeaders: [String: String] = [:],
        playlist: [PlaylistEntry]? = nil,
        sourceApp: String? = nil,
        callbackURL: URL? = nil
    ) {
        self.url = url
        self.origin = origin
        self.title = title
        self.startAt = startAt
        self.httpHeaders = httpHeaders
        self.playlist = playlist
        self.sourceApp = sourceApp
        self.callbackURL = callbackURL
    }

    /// A one line description for logs and the diagnostics screen.
    public var debugSummary: String {
        "\(origin.rawValue)/\(sourceApp ?? "-") \(url.absoluteString)"
    }
}

/// One entry of an m3u/m3u8 playlist.
public struct PlaylistEntry: Equatable, Sendable, Codable {
    /// Duration in seconds when the playlist declares one, otherwise nil.
    public var duration: TimeInterval?
    /// Display title, usually from the `#EXTINF` line.
    public var title: String?
    /// The stream URL, already resolved against the playlist's own location.
    public var url: URL

    public init(duration: TimeInterval? = nil, title: String? = nil, url: URL) {
        self.duration = duration
        self.title = title
        self.url = url
    }
}
