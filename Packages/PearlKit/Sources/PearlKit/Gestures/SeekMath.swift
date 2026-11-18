import Foundation

/// Every number behind the gestures, isolated so it can be tested without a
/// screen. This is where the feature Outplayer does not have lives: hold to
/// fast forward.
public enum SeekMath {
    /// Which third of the picture a tap landed in.
    public enum TapZone: String, Sendable {
        case back, center, forward
    }

    /// How far a horizontal drag moves playback. `.fine` is for second level
    /// accuracy, `.smart` ramps from seconds to a fraction of the runtime the
    /// further you drag, which is what feels right on a long movie.
    public enum ScrubPrecision: String, Codable, Sendable, CaseIterable {
        case fine
        case balanced
        case smart
        case coarse

        public var displayName: String {
            switch self {
            case .fine: return "Fine (seconds)"
            case .balanced: return "Balanced"
            case .smart: return "Smart ramp"
            case .coarse: return "Coarse (jump)"
            }
        }
    }

    /// Speed while the finger is held down and dragged vertically.
    ///
    /// `verticalOffset` is how far the finger moved from where it started, in
    /// points of screen, positive downwards. Dragging up raises the speed from
    /// `base` to `max`, dragging back down lowers it again. Holding still, or
    /// dragging down past the start, stays at `base`.
    public static func holdSpeed(
        verticalOffset: CGFloat,
        base: Float = 2,
        maximum: Float = 8,
        travel: CGFloat = 220
    ) -> Float {
        guard travel > 0, maximum > base else { return base }
        let fraction = Swift.min(Swift.max(-verticalOffset / travel, 0), 1)
        let raw = base + Float(fraction) * (maximum - base)
        // Quarter steps: a speed readout that jumps 2.0 / 2.25 / 2.5 reads as
        // noise, so snap and keep the label short.
        let snapped = (raw * 4).rounded() / 4
        return Swift.min(Swift.max(snapped, base), maximum)
    }

    /// Seconds to move for a horizontal scrub of `translation` points.
    ///
    /// `width` is the width of the surface the drag happens on, `duration` the
    /// length of the media. A zero or unknown duration falls back to seconds
    /// per point so the gesture still does something sensible on a live stream.
    public static func scrubDelta(
        translation: CGFloat,
        width: CGFloat,
        duration: TimeInterval,
        precision: ScrubPrecision
    ) -> TimeInterval {
        guard width > 0, translation != 0 else { return 0 }
        let fraction = Double(translation / width)
        let magnitude = abs(fraction)
        let signed = fraction < 0 ? -1.0 : 1.0

        switch precision {
        case .fine:
            return signed * min(magnitude * 30, 30)
        case .balanced:
            return signed * min(magnitude * 120, 120)
        case .coarse:
            let usable = duration > 0 ? duration : 3600
            return signed * min(magnitude * usable * 0.5, usable * 0.5)
        case .smart:
            let usable = duration > 0 ? duration : 3600
            // First 20 percent of the drag is second level, after that it ramps
            // into a share of the runtime, so a long drag across the screen
            // covers a movie.
            let fineSpan = 0.20
            if magnitude <= fineSpan {
                return signed * min(magnitude * 75, 15)
            }
            let ramp = magnitude - fineSpan
            let span = 0.80
            let rampSeconds = min(ramp / span, 1.0) * usable * 0.6
            return signed * (15 + rampSeconds)
        }
    }

    /// Which zone a tap landed in. `edgeFraction` is how far in from each side
    /// counts as the back or forward zone (0.3 means 30 percent of the width).
    public static func tapZone(
        x: CGFloat,
        width: CGFloat,
        edgeFraction: CGFloat = 0.3
    ) -> TapZone {
        guard width > 0 else { return .center }
        let clampedX = min(max(x, 0), width)
        let edge = width * min(max(edgeFraction, 0.1), 0.45)
        if clampedX <= edge { return .back }
        if clampedX >= width - edge { return .forward }
        return .center
    }

    /// Clamps a seek target into a playable range, leaving a hair of headroom so
    /// landing exactly on the end does not immediately fire "finished".
    public static func clampSeek(_ time: TimeInterval, duration: TimeInterval) -> TimeInterval {
        guard duration > 0 else { return max(time, 0) }
        let limit = max(duration - 0.25, 0)
        return min(max(time, 0), limit)
    }

    /// Where the thumbnail strip should sample from while scrubbing. Returns
    /// `count` evenly spaced times, keeping the ends off the very first and last
    /// frames where a decoder often returns nothing useful.
    public static func thumbnailTimes(duration: TimeInterval, count: Int) -> [TimeInterval] {
        guard duration > 0, count > 0 else { return [] }
        let head = min(duration * 0.02, 5)
        let tail = duration - min(duration * 0.02, 5)
        guard count > 1 else { return [(head + tail) / 2] }
        let step = (tail - head) / Double(count - 1)
        return (0..<count).map { head + Double($0) * step }
    }

    /// Auto-hide delay in seconds for the control overlay, after any
    /// interaction. Zero or less means "never hide".
    public static func resolvedAutoHideDelay(_ configured: Double) -> Double? {
        configured <= 0 ? nil : configured
    }

    /// Where a hold to fast forward should resume seeking from, when the user
    /// was already holding at a raised speed.
    public static func holdTarget(
        time: TimeInterval,
        elapsed: TimeInterval,
        speed: Float,
        duration: TimeInterval
    ) -> TimeInterval {
        clampSeek(time + elapsed * Double(speed), duration: duration)
    }
}
