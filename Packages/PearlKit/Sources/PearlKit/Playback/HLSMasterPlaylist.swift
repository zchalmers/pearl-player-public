import Foundation

/// Master HLS playlist parsing, which is how Pearl offers a quality picker.
///
/// libvlc picks its own adaptive variant, and exposes no API to pin one. So the
/// picker works the other way round: Pearl fetches the master playlist, lists
/// the variants, and when the user picks one it plays that variant's URI
/// directly. "Auto" hands the master playlist back to the engine.
public enum HLSMasterPlaylist {
    public struct Variant: Equatable, Sendable, Identifiable {
        /// Bitrate in bits per second.
        public var bandwidth: Int
        /// Average bandwidth when the playlist declares one.
        public var averageBandwidth: Int?
        public var width: Int?
        public var height: Int?
        public var frameRate: Double?
        public var codecs: String?
        public var isAudioOnly: Bool
        public var url: URL

        public var id: String { url.absoluteString }

        public init(
            bandwidth: Int,
            averageBandwidth: Int? = nil,
            width: Int? = nil,
            height: Int? = nil,
            frameRate: Double? = nil,
            codecs: String? = nil,
            isAudioOnly: Bool = false,
            url: URL
        ) {
            self.bandwidth = bandwidth
            self.averageBandwidth = averageBandwidth
            self.width = width
            self.height = height
            self.frameRate = frameRate
            self.codecs = codecs
            self.isAudioOnly = isAudioOnly
            self.url = url
        }

        /// "1080p", "720p60", "Audio only", or the raw bitrate as a last resort.
        /// Frame rate only appears when it is high enough to matter to a human.
        public var label: String {
            if isAudioOnly { return "Audio only" }
            if let height {
                if let frameRate, frameRate >= 50 { return "\(height)p\(Int(frameRate.rounded()))" }
                return "\(height)p"
            }
            return "\(bandwidth / 1000) kbps"
        }

        /// "8.4 Mbps".
        public var bandwidthLabel: String {
            let mbps = Double(bandwidth) / 1_000_000
            if mbps >= 1 { return String(format: "%.1f Mbps", mbps) }
            return "\(bandwidth / 1000) kbps"
        }
    }

    /// Returns the variants of a master playlist, best first. Empty when the
    /// text is a media playlist (no `#EXT-X-STREAM-INF`), which is the signal
    /// that there is no quality choice to offer.
    public static func variants(in text: String, baseURL: URL?) -> [Variant] {
        var variants: [Variant] = []
        var pending: [String: String] = [:]
        var isIFrameOnly = false

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("#EXT-X-STREAM-INF:") || line.hasPrefix("#EXT-X-I-FRAME-STREAM-INF:") {
                isIFrameOnly = line.hasPrefix("#EXT-X-I-FRAME")
                let payload = line.split(separator: ":", maxSplits: 1).last.map(String.init) ?? ""
                pending = attributes(in: payload)
                continue
            }
            if line.hasPrefix("#") { continue }
            guard !pending.isEmpty, let url = resolve(line, baseURL: baseURL) else { continue }
            // I-frame only streams are trick-play tracks, not watchable quality.
            if !isIFrameOnly {
                variants.append(makeVariant(pending, url: url))
            }
            pending = [:]
            isIFrameOnly = false
        }

        return variants.sorted { lhs, rhs in
            if lhs.isAudioOnly != rhs.isAudioOnly { return !lhs.isAudioOnly }
            return lhs.bandwidth > rhs.bandwidth
        }
    }

    /// True when the text looks like an HLS playlist at all.
    public static func isPlaylist(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#EXTM3U")
    }

    private static func makeVariant(_ attributes: [String: String], url: URL) -> Variant {
        let bandwidth = Int(attributes["bandwidth"] ?? "") ?? 0
        let average = Int(attributes["average-bandwidth"] ?? "")
        let codecs = attributes["codecs"]
        var width: Int?
        var height: Int?
        if let resolution = attributes["resolution"] {
            let parts = resolution.lowercased().split(separator: "x")
            if parts.count == 2 {
                width = Int(parts[0])
                height = Int(parts[1])
            }
        }
        var frameRate: Double?
        if let value = attributes["frame-rate"] {
            frameRate = Double(value)
        }
        return Variant(
            bandwidth: bandwidth,
            averageBandwidth: average,
            width: width,
            height: height,
            frameRate: frameRate,
            codecs: codecs,
            isAudioOnly: height == nil && codecs?.lowercased().hasPrefix("mp4a") == true,
            url: url
        )
    }

    private static func attributes(in payload: String) -> [String: String] {
        var result: [String: String] = [:]
        var remainder = payload[...]
        while true {
            guard let equalsIndex = remainder.firstIndex(of: "=") else { break }
            let prefix = remainder[remainder.startIndex..<equalsIndex]
            let key =
                prefix
                .split(whereSeparator: { $0 == "," || $0 == " " })
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
                let end = unquoted.firstIndex(of: ",") ?? unquoted.endIndex
                value = String(unquoted[unquoted.startIndex..<end])
                next = end
            }
            if !key.isEmpty { result[key] = value }
            guard next < remainder.endIndex else { break }
            remainder = remainder[next...]
        }
        return result
    }

    private static func resolve(_ value: String, baseURL: URL?) -> URL? {
        if let absolute = URL(string: value), absolute.scheme != nil { return absolute }
        guard let baseURL else { return nil }
        return URL(string: value, relativeTo: baseURL)?.absoluteURL
    }
}
