import Foundation
import Testing

@testable import PearlKit

@Suite("Hold to fast forward and the rest of the gesture maths")
struct SeekMathTests {
    @Test("Holding still is the base speed, dragging up climbs to the maximum")
    func holdSpeed() {
        #expect(SeekMath.holdSpeed(verticalOffset: 0) == 2)
        #expect(SeekMath.holdSpeed(verticalOffset: 60) == 2, "dragging down never goes below base")
        #expect(SeekMath.holdSpeed(verticalOffset: -110) == 5)
        #expect(SeekMath.holdSpeed(verticalOffset: -220) == 8)
        #expect(SeekMath.holdSpeed(verticalOffset: -1000) == 8, "clamped at the maximum")
    }

    @Test("Hold speed is monotonic and lands on quarter steps")
    func holdSpeedMonotonic() {
        var previous: Float = 0
        for offset in stride(from: 0, through: -400, by: -4) {
            let speed = SeekMath.holdSpeed(verticalOffset: CGFloat(offset))
            #expect(speed >= previous)
            #expect((speed * 4).rounded() == speed * 4)
            previous = speed
        }
    }

    @Test("Hold speed honours a custom base and maximum")
    func holdSpeedCustom() {
        #expect(SeekMath.holdSpeed(verticalOffset: 0, base: 1.5, maximum: 3) == 1.5)
        #expect(SeekMath.holdSpeed(verticalOffset: -220, base: 1.5, maximum: 3) == 3)
    }

    @Test("Fine scrubbing is second level and capped")
    func fineScrub() {
        let delta = SeekMath.scrubDelta(
            translation: 100, width: 400, duration: 7200, precision: .fine)
        #expect(abs(delta - 7.5) < 0.001)
        let capped = SeekMath.scrubDelta(
            translation: 1000, width: 400, duration: 7200, precision: .fine)
        #expect(abs(capped - 30) < 0.001)
    }

    @Test("Smart scrubbing ramps from seconds into a share of the runtime")
    func smartScrub() {
        let small = SeekMath.scrubDelta(
            translation: 20, width: 400, duration: 7200, precision: .smart)
        #expect(abs(small - 3.75) < 0.001, "a 5 percent drag is second level")

        let big = SeekMath.scrubDelta(
            translation: 400, width: 400, duration: 7200, precision: .smart)
        #expect(big > 1000, "a full width drag on a 2 hour movie covers a lot")
        #expect(big < 7200, "but never more than the runtime")
    }

    @Test("Scrub direction follows the finger")
    func scrubDirection() {
        let forward = SeekMath.scrubDelta(translation: 50, width: 400, duration: 100, precision: .balanced)
        let backward = SeekMath.scrubDelta(translation: -50, width: 400, duration: 100, precision: .balanced)
        #expect(forward > 0)
        #expect(backward == -forward)
    }

    @Test("Scrubbing survives a live stream with no known duration")
    func scrubLive() {
        let delta = SeekMath.scrubDelta(translation: 100, width: 400, duration: 0, precision: .coarse)
        #expect(delta > 0)
        #expect(delta.isFinite)
    }

    @Test("Tap zones split the picture into three")
    func tapZones() {
        #expect(SeekMath.tapZone(x: 20, width: 400) == .back)
        #expect(SeekMath.tapZone(x: 200, width: 400) == .center)
        #expect(SeekMath.tapZone(x: 390, width: 400) == .forward)
    }

    @Test("Seeking is clamped inside the media")
    func clamp() {
        #expect(SeekMath.clampSeek(-10, duration: 100) == 0)
        #expect(SeekMath.clampSeek(50, duration: 100) == 50)
        #expect(SeekMath.clampSeek(1000, duration: 100) == 99.75)
        #expect(SeekMath.clampSeek(1000, duration: 0) == 1000)
    }

    @Test("Thumbnail samples stay off the very ends")
    func thumbnails() {
        let times = SeekMath.thumbnailTimes(duration: 600, count: 5)
        #expect(times.count == 5)
        #expect(times.first! > 0)
        #expect(times.last! < 600)
        #expect(times == times.sorted())
    }

    @Test("Auto hide delay resolves from settings")
    func autoHide() {
        #expect(SeekMath.resolvedAutoHideDelay(3.5) == 3.5)
        #expect(SeekMath.resolvedAutoHideDelay(0) == nil)
        #expect(SeekMath.resolvedAutoHideDelay(-1) == nil)
    }

    @Test("Holding forward moves playback by speed times elapsed")
    func holdTarget() {
        #expect(SeekMath.holdTarget(time: 10, elapsed: 5, speed: 3, duration: 100) == 25)
        #expect(SeekMath.holdTarget(time: 90, elapsed: 10, speed: 8, duration: 100) == 99.75)
    }
}

@Suite("Formatting")
struct FormatTests {
    @Test("Durations read the way a player shows them")
    func durations() {
        #expect(Format.duration(0) == "0:00")
        #expect(Format.duration(63) == "1:03")
        #expect(Format.duration(3725) == "1:02:05")
        #expect(Format.duration(-10) == "-0:10")
        #expect(Format.duration(.nan) == "--:--")
    }

    @Test("Seek deltas carry a sign and a unit")
    func deltas() {
        #expect(Format.seekDelta(10) == "+10s")
        #expect(Format.seekDelta(-5) == "-5s")
        #expect(Format.seekDelta(0.4) == "0s")
    }

    @Test("Speeds read cleanly")
    func rates() {
        #expect(Format.rate(1) == "1x")
        #expect(Format.rate(2.5) == "2.50x".replacingOccurrences(of: "0x", with: "x"))
        #expect(Format.rate(0.5) == "0.5x")
    }

    @Test("Quality labels include frame rate only when it matters")
    func quality() {
        #expect(Format.qualityLabel(width: 1920, height: 1080, frameRate: 23.976) == "1080p@23.98")
        #expect(Format.qualityLabel(width: 1280, height: 720, frameRate: 60) == "720p60")
        #expect(Format.qualityLabel(width: 0, height: 0, frameRate: nil) == "--")
    }

    @Test("A title comes out of a messy URL")
    func titles() {
        let url = URL(string: "https://cdn.example.com/shows/Some_Movie%20(2024).mkv")!
        #expect(Format.title(from: url) == "Some Movie (2024)")
    }

    @Test("File names are made safe for snapshots")
    func safeNames() {
        #expect(Format.safeFileName("a/b:c?d") == "a-b-c-d")
        #expect(Format.safeFileName("   ") == "pearl")
    }

    @Test("Language codes match across the two letter and three letter forms")
    func languages() {
        #expect(LanguageNames.name(for: "en") == "English")
        #expect(LanguageNames.name(for: "eng") == "English")
        #expect(LanguageNames.name(for: "en-GB") == "English")
        #expect(LanguageNames.name(for: "xx") == "XX")
        #expect(LanguageNames.name(for: nil) == "Unknown")
        #expect(LanguageNames.matches("en", "eng"))
        #expect(LanguageNames.matches("en-US", "en-GB"))
        #expect(!LanguageNames.matches("en", "fr"))
        #expect(!LanguageNames.matches(nil, "en"))
    }
}
