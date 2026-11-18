import CoreGraphics
import Foundation
import PearlKit
import UIKit

/// What the player is doing right now.
public enum PlaybackState: Equatable, Sendable {
    case idle
    case loading
    case playing
    case paused
    case buffering(Double)
    case ended
    case failed(String)

    public var isPlaying: Bool {
        if case .playing = self { return true }
        return false
    }

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .loading: return "Loading"
        case .playing: return "Playing"
        case .paused: return "Paused"
        case .buffering(let progress): return progress > 0 ? "Buffering \(Int(progress * 100))%" : "Buffering"
        case .ended: return "Finished"
        case .failed(let message): return message
        }
    }
}

/// One selectable audio or subtitle track, engine independent.
public struct TrackInfo: Identifiable, Equatable, Sendable, Codable {
    public enum Kind: String, Sendable, Codable {
        case audio, video, subtitle
    }

    public var id: String
    public var kind: Kind
    public var name: String
    public var language: String?
    public var codec: String?
    public var channels: Int?
    public var bitrate: Int?
    public var isSelected: Bool

    public init(
        id: String,
        kind: Kind,
        name: String,
        language: String? = nil,
        codec: String? = nil,
        channels: Int? = nil,
        bitrate: Int? = nil,
        isSelected: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.language = language
        self.codec = codec
        self.channels = channels
        self.bitrate = bitrate
        self.isSelected = isSelected
    }

    /// "English - AC3 5.1" style label for the picker.
    public var detailLabel: String {
        var parts: [String] = []
        if let language { parts.append(LanguageNames.name(for: language)) }
        if let codec { parts.append(codec.uppercased()) }
        if let channels {
            parts.append(
                channels >= 6 ? "\(channels / 2).1".replacingOccurrences(of: ".1", with: ".1") : "\(channels)ch")
        }
        if parts.isEmpty { parts.append(name) }
        return parts.joined(separator: " - ")
    }
}

/// Aspect ratio choices offered in the controls.
public enum AspectRatioMode: String, CaseIterable, Sendable, Codable {
    case fit
    case fill
    case stretch
    case original
    case r16x9
    case r4x3
    case r1x1
    case r235x1
    case custom

    public var displayName: String {
        switch self {
        case .fit: return "Fit"
        case .fill: return "Fill"
        case .stretch: return "Stretch"
        case .original: return "Original"
        case .r16x9: return "16:9"
        case .r4x3: return "4:3"
        case .r1x1: return "1:1"
        case .r235x1: return "2.35:1"
        case .custom: return "Custom"
        }
    }

    /// libvlc aspect ratio string, or nil for the fit modes which are handled by
    /// the engine's own fit mode instead.
    public var vlcAspectRatio: String? {
        switch self {
        case .fit, .fill: return nil
        case .stretch: return nil
        case .original: return ""
        case .r16x9: return "16:9"
        case .r4x3: return "4:3"
        case .r1x1: return "1:1"
        case .r235x1: return "2.35:1"
        case .custom: return nil
        }
    }
}

/// Live numbers for the stats overlay. All of it comes from the engine.
public struct PlaybackStats: Equatable, Sendable {
    public var videoCodec: String?
    public var audioCodec: String?
    public var width: Int
    public var height: Int
    public var frameRate: Double?
    public var videoBitrate: Double
    public var audioBitrate: Double
    public var droppedFrames: Int
    public var decodedVideo: Int
    public var displayFPS: Double
    public var bufferLevel: Double
    public var demuxBitrate: Double

    public init(
        videoCodec: String? = nil,
        audioCodec: String? = nil,
        width: Int = 0,
        height: Int = 0,
        frameRate: Double? = nil,
        videoBitrate: Double = 0,
        audioBitrate: Double = 0,
        droppedFrames: Int = 0,
        decodedVideo: Int = 0,
        displayFPS: Double = 0,
        bufferLevel: Double = 0,
        demuxBitrate: Double = 0
    ) {
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.videoBitrate = videoBitrate
        self.audioBitrate = audioBitrate
        self.droppedFrames = droppedFrames
        self.decodedVideo = decodedVideo
        self.displayFPS = displayFPS
        self.bufferLevel = bufferLevel
        self.demuxBitrate = demuxBitrate
    }

    public static let empty = PlaybackStats()

    /// The lines the overlay draws, ready formatted.
    public var lines: [(String, String)] {
        [
            ("Quality", Format.qualityLabel(width: width, height: height, frameRate: frameRate)),
            ("Video", videoCodec?.uppercased() ?? "--"),
            ("Audio", audioCodec?.uppercased() ?? "--"),
            ("Video bitrate", Format.bitrate(videoBitrate)),
            ("Audio bitrate", Format.bitrate(audioBitrate)),
            ("Display FPS", displayFPS > 0 ? String(format: "%.1f", displayFPS) : "--"),
            ("Dropped frames", "\(droppedFrames)"),
            ("Decoded frames", "\(decodedVideo)"),
            ("Buffer", bufferLevel > 0 ? String(format: "%.2fs", bufferLevel) : "--"),
            ("Demux rate", Format.bitrate(demuxBitrate))
        ]
    }
}
