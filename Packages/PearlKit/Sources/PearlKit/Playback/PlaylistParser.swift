import Foundation

/// m3u / m3u8 (non master) playlist parsing.
///
/// Used for two things: entries of a Stremio M3U handoff, and local `.m3u`
/// files in the library.
public enum PlaylistParser {
    /// Parses playlist text. `baseURL` resolves relative entries, which is what
    /// a remote playlist needs.
    public static func parse(_ text: String, baseURL: URL? = nil) -> [PlaylistEntry] {
        var entries: [PlaylistEntry] = []
        var pendingDuration: TimeInterval?
        var pendingTitle: String?
        var pendingTags: [String: String] = [:]

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("#") {
                let upper = line.uppercased()
                if upper.hasPrefix("#EXTINF:") {
                    let payload = String(line.dropFirst("#EXTINF:".count))
                    let parts = payload.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
                    let durationField = parts.first.map(String.init) ?? ""
                    if let seconds = parseDuration(durationField) {
                        pendingDuration = seconds > 0 ? seconds : nil
                    }
                    if parts.count > 1 {
                        let title = parts[1].trimmingCharacters(in: .whitespaces)
                        pendingTitle = title.isEmpty ? nil : title
                    }
                    pendingTags = parseAttributes(in: durationField)
                }
                continue
            }

            // Anything not a comment and not a tag is an entry URL.
            if line.hasPrefix("#EXT") { continue }
            guard let url = resolve(line, baseURL: baseURL) else { continue }
            let title = pendingTitle ?? pendingTags["tvg-name"]
            entries.append(PlaylistEntry(duration: pendingDuration, title: title, url: url))
            pendingDuration = nil
            pendingTitle = nil
            pendingTags = [:]
        }

        return entries
    }

    /// Reads a local playlist file.
    public static func parse(fileURL: URL) throws -> [PlaylistEntry] {
        let text = try String(contentsOf: fileURL, encoding: .utf8)
        return parse(text, baseURL: fileURL.deletingLastPathComponent())
    }

    /// `123`, `123.5` or `-1` (which means "live, no duration").
    private static func parseDuration(_ field: String) -> TimeInterval? {
        let head = field.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? field
        return TimeInterval(head)
    }

    private static func parseAttributes(in field: String) -> [String: String] {
        var attributes: [String: String] = [:]
        var remainder = field[...]
        while true {
            guard let equalsIndex = remainder.firstIndex(of: "=") else { break }
            let prefix = remainder[remainder.startIndex..<equalsIndex]
            let key =
                prefix
                .split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "," })
                .last?
                .lowercased() ?? ""
            let afterEquals = remainder.index(after: equalsIndex)
            var next = afterEquals
            var value = ""
            if afterEquals < remainder.endIndex, remainder[afterEquals] == "\"" {
                let quoted = remainder[remainder.index(after: afterEquals)...]
                if let close = quoted.firstIndex(of: "\"") {
                    value = String(quoted[quoted.startIndex..<close])
                    next = quoted.index(after: close)
                } else {
                    value = String(quoted)
                    next = remainder.endIndex
                }
            } else {
                let unquoted = remainder[afterEquals...]
                let end = unquoted.firstIndex(where: { $0 == " " || $0 == "," }) ?? unquoted.endIndex
                value = String(unquoted[unquoted.startIndex..<end])
                next = end
            }
            if !key.isEmpty { attributes[key] = value }
            guard next < remainder.endIndex else { break }
            remainder = remainder[next...]
        }
        return attributes
    }

    private static func resolve(_ value: String, baseURL: URL?) -> URL? {
        if let absolute = URL(string: value), absolute.scheme != nil {
            return absolute
        }
        guard let baseURL else { return nil }
        return URL(string: value, relativeTo: baseURL)?.absoluteURL
    }
}
