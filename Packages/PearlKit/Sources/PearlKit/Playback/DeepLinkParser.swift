import Foundation

/// Turns every URL form that can reach Pearl into either a `PlayRequest` or a
/// clear reason why it cannot be played.
///
/// The forms are not invented here, they are what the other side actually
/// sends. Stremio's `stremio-core` builds these exact strings in
/// `src/deep_links/mod.rs`:
///
/// ```
/// outplayer      -> outplayer://https://host/stream.mkv      (scheme swapped, not encoded)
/// vlc            -> vlc-x-callback://x-callback-url/stream?url=<percent encoded>
/// infuse         -> infuse://x-callback-url/play?url=<enc>&x-success=<enc>&position=<sec>
/// m3u playlist   -> a data: URI holding the playlist
/// ```
///
/// Add to that: the same links with the payload percent encoded, `vlc://` short
/// form, our own `pearl://` scheme, plain media URLs and local files.
public enum DeepLinkParser {
    /// Schemes Pearl claims in Info.plist.
    public static let handledSchemes: Set<String> = [
        "pearl", "pearlplayer", "outplayer", "vlc-x-callback", "vlc"
    ]

    /// Schemes that are already a stream, so no unwrapping is needed.
    public static let streamSchemes: Set<String> = [
        "http", "https", "rtsp", "rtsps", "rtmp", "rtmps", "mms",
        "ftp", "sftp", "smb", "nfs", "file", "udp", "rtp", "srt"
    ]

    /// Schemes we understand but cannot play without a torrent or stream engine.
    public static let unplayableSchemes: Set<String> = ["magnet", "acestream", "torrent"]

    /// Keys that carry the stream inside a wrapper URL.
    private static let streamKeys = ["url", "stream", "src", "source", "link"]

    /// Keys that carry a resume position.
    private static let positionKeys = ["position", "pos", "t", "time", "start", "resume"]

    /// Keys that carry the detail URL to return to.
    private static let callbackKeys = ["x-success", "x_success", "success", "callback", "lastPlayedUrl"]

    public enum Outcome: Equatable, Sendable {
        /// Play this.
        case playback(PlayRequest)
        /// Understood, cannot play, with a reason a human can read.
        case unsupported(reason: String, raw: String)
        /// A magnet or torrent link. Pearl has no torrent engine, so say so
        /// plainly instead of silently failing.
        case needsTorrentEngine(raw: String)

        public var playRequest: PlayRequest? {
            if case .playback(let request) = self { return request }
            return nil
        }
    }

    public static func parse(_ raw: String) -> Outcome {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .unsupported(reason: "The link was empty.", raw: raw)
        }

        let lower = trimmed.lowercased()

        // A playlist handed over as a data URI (Stremio's "M3U Playlist" option).
        if lower.hasPrefix("data:") {
            return playlistFromDataURI(trimmed)
        }

        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else {
            return .unsupported(reason: "That is not a URL Pearl recognises.", raw: raw)
        }

        if unplayableSchemes.contains(scheme) {
            return .needsTorrentEngine(raw: trimmed)
        }

        if streamSchemes.contains(scheme) {
            return .playback(PlayRequest(url: url, origin: .url, sourceApp: scheme))
        }

        guard handledSchemes.contains(scheme) else {
            return .unsupported(reason: "Pearl does not handle the \(scheme) scheme.", raw: raw)
        }

        return unwrap(trimmed, scheme: scheme)
    }

    public static func parse(_ url: URL) -> Outcome {
        parse(url.absoluteString)
    }

    // MARK: - Unwrapping

    private static func unwrap(_ raw: String, scheme: String) -> Outcome {
        // Everything after "<scheme>://" (or "<scheme>:" when there is no //).
        var rest = String(raw.dropFirst(scheme.count))
        while rest.hasPrefix(":") || rest.hasPrefix("/") {
            rest.removeFirst()
        }
        guard !rest.isEmpty else {
            return .unsupported(reason: "The \(scheme) link carried no stream.", raw: raw)
        }

        var params: [String: String] = [:]
        var payload = rest

        // The x-callback-url shapes put the payload in the query string.
        if rest.lowercased().hasPrefix("x-callback-url/") || rest.lowercased().hasPrefix("?") {
            params = queryParameters(in: rest)
        }

        if let fromQuery = streamKeys.compactMap({ params[$0] }).first, !fromQuery.isEmpty {
            payload = fromQuery
        } else if !rest.lowercased().hasPrefix("x-callback-url/"), let questionMark = rest.firstIndex(of: "?") {
            // "outplayer://https://host/x.mkv?token=1" is one whole URL: the
            // query belongs to the stream, not to us, so only pull parameters
            // out when the prefix is not already a playable URL.
            let head = String(rest[rest.startIndex..<questionMark])
            if !looksLikeStream(head) {
                params = queryParameters(in: rest)
                if let fromQuery = streamKeys.compactMap({ params[$0] }).first, !fromQuery.isEmpty {
                    payload = fromQuery
                }
            }
        }

        // Percent decoding can be applied zero, one or two times depending on
        // the app that built the link, and the payload can itself be wrapped in
        // another one of our schemes. Try each, keep the first that works.
        for candidate in decodeCandidates(payload) {
            if let url = streamURL(from: stripNestedWrappers(candidate)) {
                return .playback(makeRequest(url: url, params: params, sourceApp: scheme))
            }
        }

        return .unsupported(
            reason: "The \(scheme) link did not contain a stream Pearl can open.",
            raw: raw
        )
    }

    /// Removes any of our own schemes wrapped around the payload, so
    /// `pearl://outplayer://https://host/x` still lands on the stream.
    private static func stripNestedWrappers(_ value: String) -> String {
        var current = value
        var rounds = 0
        while rounds < 5 {
            let lower = current.lowercased()
            guard let scheme = handledSchemes.first(where: { lower.hasPrefix($0 + "://") }) else { break }
            var rest = String(current.dropFirst(scheme.count))
            while rest.hasPrefix(":") || rest.hasPrefix("/") { rest.removeFirst() }
            guard !rest.isEmpty else { break }
            current = rest
            rounds += 1
        }
        return current
    }

    private static func looksLikeStream(_ value: String) -> Bool {
        guard let separator = value.range(of: "://") else { return false }
        let scheme = value[value.startIndex..<separator.lowerBound].lowercased()
        return streamSchemes.contains(scheme) || unplayableSchemes.contains(scheme)
    }

    /// Strips a leading slash or two, then validates the result is a real URL.
    private static func streamURL(from candidate: String) -> URL? {
        var value = repairStrippedScheme(candidate.trimmingCharacters(in: .whitespacesAndNewlines))
        while value.hasPrefix("/") {
            value.removeFirst()
        }
        guard !value.isEmpty else { return nil }
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return nil }
        guard streamSchemes.contains(scheme) else { return nil }
        // Reject the shape-only wrappers: "ftp://" parses but has nothing to open.
        let hasHost = (url.host?.isEmpty == false)
        let hasPath = !url.path.isEmpty
        guard hasHost || hasPath else { return nil }
        return url
    }

    /// iOS hands a wrapped URL to the app with the inner scheme's colon eaten:
    /// `outplayer://https://host/x.mkv` arrives as `outplayer://https//host/x.mkv`,
    /// so the payload parses as scheme `https` with no colon and is thrown away.
    /// Seen in the simulator's LaunchServices log and on the phone. Put the colon
    /// back before giving up on the candidate.
    private static func repairStrippedScheme(_ value: String) -> String {
        for scheme in streamSchemes {
            let bare = scheme + "//"
            guard value.lowercased().hasPrefix(bare) else { continue }
            let rest = value.dropFirst(bare.count)
            // "https//host/x" only. A real URL has the colon, so this cannot fire
            // on a well formed one.
            return scheme + "://" + rest
        }
        return value
    }

    private static func decodeCandidates(_ value: String) -> [String] {
        var candidates = [value]
        var current = value
        for _ in 0..<2 {
            let next = current.removingPercentEncoding ?? current
            if next == current { break }
            candidates.append(next)
            current = next
        }
        return candidates
    }

    private static func makeRequest(
        url: URL,
        params: [String: String],
        sourceApp: String
    ) -> PlayRequest {
        var request = PlayRequest(url: url, origin: .externalApp, sourceApp: sourceApp)

        if let position = positionKeys.compactMap({ params[$0] }).first, let seconds = Double(position) {
            request.startAt = seconds
        }
        if let title = params["filename"] ?? params["title"], !title.isEmpty {
            request.title = title
        }
        if let callback = callbackKeys.compactMap({ params[$0] }).first,
            let callbackURL = URL(string: callback), callbackURL.scheme != nil
        {
            request.callbackURL = callbackURL
        }
        if let headerField = params["headers"] ?? params["http-headers"] {
            request.httpHeaders = parseHeaders(headerField)
        }
        if handledSchemes.contains(sourceApp) && !isOurOwnScheme(sourceApp) {
            request.origin = .stremio
        }
        return request
    }

    private static func isOurOwnScheme(_ scheme: String) -> Bool {
        scheme == "pearl" || scheme == "pearlplayer"
    }

    /// `User-Agent:VLC/1|Referer:https://x`, `a=b&c=d` and `A:1;B:2` all work.
    public static func parseHeaders(_ field: String) -> [String: String] {
        var headers: [String: String] = [:]
        let pairs = field.split(whereSeparator: { $0 == "|" || $0 == "&" || $0 == ";" })
        for pair in pairs {
            var parts = pair.split(separator: ":", maxSplits: 1)
            if parts.count < 2 {
                // The "a=b" shape, which the query string form produces.
                parts = pair.split(separator: "=", maxSplits: 1)
            }
            guard parts.count == 2 else { continue }
            // Only the first colon or equals splits: header values contain both.
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty, !value.isEmpty else { continue }
            headers[key] = value
        }
        return headers
    }

    // MARK: - Query

    static func queryParameters(in value: String) -> [String: String] {
        guard let questionMark = value.firstIndex(of: "?") else { return [:] }
        let query = value[value.index(after: questionMark)...]
        var result: [String: String] = [:]
        for pair in query.split(separator: "&") {
            let parts = pair.split(separator: "=", maxSplits: 1)
            guard let name = parts.first?.removingPercentEncoding?.lowercased() else { continue }
            let value = parts.count > 1 ? decodeQueryValue(String(parts[1])) : ""
            if result[name] == nil { result[name] = value }
        }
        return result
    }

    private static func decodeQueryValue(_ value: String) -> String {
        let plusDecoded = value.replacingOccurrences(of: "+", with: " ")
        return plusDecoded.removingPercentEncoding ?? plusDecoded
    }

    // MARK: - Playlists

    /// Stremio's M3U handoff is `data:...;base64,<payload>` or a plain data URI.
    private static func playlistFromDataURI(_ raw: String) -> Outcome {
        guard let comma = raw.firstIndex(of: ",") else {
            return .unsupported(reason: "The playlist link was malformed.", raw: raw)
        }
        let header = raw[raw.startIndex..<comma].lowercased()
        let body = String(raw[raw.index(after: comma)...])
        let text: String?
        if header.contains("base64") {
            if let data = Data(base64Encoded: body, options: [.ignoreUnknownCharacters]) {
                text = String(data: data, encoding: .utf8)
            } else {
                text = body.removingPercentEncoding
            }
        } else {
            text = body.removingPercentEncoding ?? body
        }
        guard let playlistText = text, !playlistText.isEmpty else {
            return .unsupported(reason: "The playlist link could not be decoded.", raw: raw)
        }
        let entries = PlaylistParser.parse(playlistText, baseURL: nil)
        guard let first = entries.first else {
            return .unsupported(reason: "The playlist was empty.", raw: raw)
        }
        var request = PlayRequest(url: first.url, origin: .stremio, title: first.title, playlist: entries)
        request.sourceApp = "m3u"
        return .playback(request)
    }
}
