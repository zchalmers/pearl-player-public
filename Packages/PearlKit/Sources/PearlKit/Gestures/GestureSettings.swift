import Foundation

/// Every gesture and its tuning knob, in one place, so the settings screen and
/// the gesture layer cannot drift apart.
public struct GestureSettings: Codable, Equatable, Sendable {
    /// Seconds moved by a double tap on the left or right third.
    public var doubleTapSeconds: TimeInterval
    /// Speed a hold starts at.
    public var holdBaseSpeed: Float
    /// Fastest speed the hold reaches when the finger drags up.
    public var holdMaxSpeed: Float
    /// How far the finger has to travel to reach `holdMaxSpeed`, in points.
    public var holdTravel: CGFloat
    /// What a horizontal drag does.
    public var scrubPrecision: SeekMath.ScrubPrecision
    /// Fraction of the width that counts as the left or right tap zone.
    public var tapZoneFraction: CGFloat
    /// Vertical drag on the left half drives brightness, not volume.
    public var verticalDragDrivesBrightness: Bool
    /// Double tap in the middle plays or pauses.
    public var doubleTapCenterTogglesPlayback: Bool
    /// Two finger tap plays or pauses.
    public var twoFingerTapTogglesPlayback: Bool
    /// Two finger vertical drag moves subtitles up and down.
    public var twoFingerDragMovesSubtitles: Bool
    /// Pinch to zoom in and out of the picture.
    public var pinchToZoom: Bool
    /// Seconds before the controls hide themselves. Zero means never.
    public var autoHideSeconds: TimeInterval
    /// Show the little overlays for seek, volume, brightness and speed.
    public var showHints: Bool
    /// Haptic ticks for gestures.
    public var haptics: Bool
    /// Keep the screen awake while playing.
    public var keepScreenAwake: Bool
    /// Prevent accidental gestures while locked.
    public var lockControls: Bool
    /// Swipe down on the video closes the player.
    public var swipeDownCloses: Bool
    /// Double tap on the very edge of the screen jumps a chapter instead.
    public var edgeDoubleTapSkipsChapter: Bool

    public init(
        doubleTapSeconds: TimeInterval = 10,
        holdBaseSpeed: Float = 2,
        holdMaxSpeed: Float = 8,
        holdTravel: CGFloat = 220,
        scrubPrecision: SeekMath.ScrubPrecision = .smart,
        tapZoneFraction: CGFloat = 0.3,
        verticalDragDrivesBrightness: Bool = true,
        doubleTapCenterTogglesPlayback: Bool = true,
        twoFingerTapTogglesPlayback: Bool = true,
        twoFingerDragMovesSubtitles: Bool = true,
        pinchToZoom: Bool = true,
        autoHideSeconds: TimeInterval = 4,
        showHints: Bool = true,
        haptics: Bool = true,
        keepScreenAwake: Bool = true,
        lockControls: Bool = false,
        swipeDownCloses: Bool = true,
        edgeDoubleTapSkipsChapter: Bool = false
    ) {
        self.doubleTapSeconds = doubleTapSeconds
        self.holdBaseSpeed = holdBaseSpeed
        self.holdMaxSpeed = holdMaxSpeed
        self.holdTravel = holdTravel
        self.scrubPrecision = scrubPrecision
        self.tapZoneFraction = tapZoneFraction
        self.verticalDragDrivesBrightness = verticalDragDrivesBrightness
        self.doubleTapCenterTogglesPlayback = doubleTapCenterTogglesPlayback
        self.twoFingerTapTogglesPlayback = twoFingerTapTogglesPlayback
        self.twoFingerDragMovesSubtitles = twoFingerDragMovesSubtitles
        self.pinchToZoom = pinchToZoom
        self.autoHideSeconds = autoHideSeconds
        self.showHints = showHints
        self.haptics = haptics
        self.keepScreenAwake = keepScreenAwake
        self.lockControls = lockControls
        self.swipeDownCloses = swipeDownCloses
        self.edgeDoubleTapSkipsChapter = edgeDoubleTapSkipsChapter
    }

    public static let `default` = GestureSettings()

    /// The choices offered for how far a double tap moves playback.
    public static let doubleTapChoices: [TimeInterval] = [5, 10, 15, 20, 30, 45, 60]

    /// The speeds offered for holding.
    public static let holdSpeedChoices: [Float] = [1.5, 2, 2.5, 3, 4, 8]

    /// Everything the settings screen says about each knob, kept next to the
    /// field it describes.
    public var isValid: Bool {
        doubleTapSeconds > 0
            && holdBaseSpeed >= 1
            && holdMaxSpeed >= holdBaseSpeed
            && holdTravel > 0
            && tapZoneFraction > 0 && tapZoneFraction < 0.5
    }
}
