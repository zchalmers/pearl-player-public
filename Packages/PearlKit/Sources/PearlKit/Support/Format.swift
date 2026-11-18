import Foundation

/// Time and size formatting shared by the player, the seek bar and the library.
public enum Format {
    /// "1:02:03" for anything an hour or longer, "2:03" below that. Negative
    /// values keep their sign, which is what a seek HUD needs.
    public static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "--:--" }
        let negative = seconds < 0
        let total = Int(seconds.magnitude.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        let body: String
        if hours > 0 {
            body = String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            body = String(format: "%d:%02d", minutes, secs)
        }
        return negative ? "-" + body : body
    }

    /// "+10s" / "-10s" for a seek HUD.
    public static func seekDelta(_ seconds: TimeInterval) -> String {
        let rounded = Int(seconds.rounded())
        if rounded == 0 { return "0s" }
        return rounded > 0 ? "+\(rounded)s" : "\(rounded)s"
    }

    /// "3x" style speed label, with one decimal only when it is not whole.
    public static func rate(_ rate: Float) -> String {
        let value = Double(rate)
        if abs(value.rounded() - value) < 0.001 {
            return "\(Int(value.rounded()))x"
        }
        return String(format: "%.2fx", value).replacingOccurrences(of: "0x", with: "x")
    }

    /// "1.4 GB" for the library and the downloads list.
    public static func fileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    /// "8.4 Mbps" for the stats overlay and the stream picker.
    public static func bitrate(_ bitsPerSecond: Double) -> String {
        guard bitsPerSecond > 0 else { return "--" }
        let mbps = bitsPerSecond / 1_000_000
        if mbps >= 1 { return String(format: "%.1f Mbps", mbps) }
        return String(format: "%.0f kbps", bitsPerSecond / 1000)
    }

    /// "1080p60" from a size and frame rate, for the stats overlay.
    public static func qualityLabel(width: Int, height: Int, frameRate: Double?) -> String {
        guard height > 0 else { return "--" }
        let base = "\(height)p"
        if let frameRate, frameRate >= 50 { return base + "\(Int(frameRate.rounded()))" }
        if let frameRate, frameRate > 0 { return base + String(format: "@%.2f", frameRate) }
        return base
    }

    /// A file name safe enough to save a snapshot or a recording as.
    public static func safeFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let cleaned = value.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "pearl" : String(trimmed.prefix(120))
    }

    /// Best effort title from a URL: the last path component, decoded, without
    /// its extension. Used for Stremio handoffs, which carry no title.
    public static func title(from url: URL) -> String {
        let last = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        let withoutExtension = (last as NSString).deletingPathExtension
        if withoutExtension.isEmpty || withoutExtension == "/" {
            return url.host ?? url.absoluteString
        }
        return withoutExtension.replacingOccurrences(of: "_", with: " ")
    }
}

/// Language codes to readable names, for track pickers.
public enum LanguageNames {
    private static let table: [String: String] = [
        "en": "English", "eng": "English", "es": "Spanish", "spa": "Spanish",
        "fr": "French", "fre": "French", "fra": "French", "de": "German", "ger": "German",
        "deu": "German", "it": "Italian", "ita": "Italian", "pt": "Portuguese",
        "por": "Portuguese", "ru": "Russian", "rus": "Russian", "ja": "Japanese",
        "jpn": "Japanese", "ko": "Korean", "kor": "Korean", "zh": "Chinese",
        "chi": "Chinese", "zho": "Chinese", "ar": "Arabic", "ara": "Arabic",
        "hi": "Hindi", "hin": "Hindi", "nl": "Dutch", "nld": "Dutch", "dut": "Dutch",
        "pl": "Polish", "pol": "Polish", "sv": "Swedish", "swe": "Swedish",
        "no": "Norwegian", "nor": "Norwegian", "da": "Danish", "dan": "Danish",
        "fi": "Finnish", "fin": "Finnish", "tr": "Turkish", "tur": "Turkish",
        "cs": "Czech", "ces": "Czech", "el": "Greek", "ell": "Greek", "he": "Hebrew",
        "heb": "Hebrew", "th": "Thai", "tha": "Thai", "vi": "Vietnamese", "vie": "Vietnamese",
        "uk": "Ukrainian", "ukr": "Ukrainian", "ro": "Romanian", "ron": "Romanian",
        "hu": "Hungarian", "hun": "Hungarian", "id": "Indonesian", "ind": "Indonesian",
        "ms": "Malay", "msa": "Malay", "fa": "Persian", "fas": "Persian"
    ]

    /// "English" for "en", "eng" and "en-US". Falls back to the raw code, in
    /// upper case, so an unknown track still reads sensibly.
    public static func name(for code: String?) -> String {
        guard let code, !code.isEmpty else { return "Unknown" }
        let base = code.split(separator: "-").first.map(String.init)?.lowercased() ?? code.lowercased()
        if let name = table[base] { return name }
        return code.uppercased()
    }

    /// True when two language codes refer to the same language.
    public static func matches(_ lhs: String?, _ rhs: String?) -> Bool {
        guard let lhs, let rhs, !lhs.isEmpty, !rhs.isEmpty else { return false }
        let left = lhs.split(separator: "-").first.map(String.init)?.lowercased() ?? lhs.lowercased()
        let right = rhs.split(separator: "-").first.map(String.init)?.lowercased() ?? rhs.lowercased()
        if left == right { return true }
        // "en" against "eng", and the other way round.
        return table[left] != nil && table[left] == table[right]
    }
}
