import PearlKit
import SwiftUI
import UIKit

/// The gesture surface.
///
/// UIKit recognisers rather than SwiftUI gestures on purpose: a video player
/// needs a long press that keeps delivering movement (the hold to fast forward),
/// a pan that decides on first direction, and a single tap that only fires when
/// the double tap does not, and SwiftUI's gesture composition makes that fight
/// the framework instead of using it.
struct GestureCatcherView: UIViewRepresentable {
    var onSingleTap: () -> Void
    var onDoubleTap: (SeekMath.TapZone, CGFloat) -> Void
    var onHoldBegan: () -> Void
    var onHoldChanged: (CGFloat) -> Void
    var onHoldEnded: () -> Void
    var onScrubBegan: () -> Void
    var onScrubChanged: (CGFloat, CGFloat) -> Void
    var onScrubEnded: () -> Void
    var onVerticalDragBegan: (Bool) -> Void
    var onVerticalDragChanged: (CGFloat, Bool) -> Void
    var onVerticalDragEnded: (Bool) -> Void
    var onPinchChanged: (CGFloat) -> Void
    var onPinchEnded: () -> Void
    var onTwoFingerTap: () -> Void
    var onSwipeDown: () -> Void
    var isEnabled: Bool

    func makeUIView(context: Context) -> GestureSurface {
        let view = GestureSurface()
        view.handler = self
        return view
    }

    func updateUIView(_ uiView: GestureSurface, context: Context) {
        uiView.handler = self
        uiView.isUserInteractionEnabled = isEnabled
    }
}

/// The UIView behind `GestureCatcherView`, so the recogniser wiring stays in one
/// place and SwiftUI only sees a view.
final class GestureSurface: UIView, UIGestureRecognizerDelegate {
    var handler: GestureCatcherView?

    private var isScrubbing = false
    private var isAdjustingVertically = false
    private var dragStartedOnLeftHalf = false
    private var lastVerticalTranslation: CGFloat = 0
    private var holdGestureActive = false
    /// Where the hold started. A long press has no `translation(in:)`, that is a
    /// pan recogniser only, so the offset is measured against this point.
    private var holdStartPoint: CGPoint = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        installGestureRecognizers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private func installGestureRecognizers() {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        singleTap.delegate = self
        addGestureRecognizer(singleTap)

        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.delegate = self
        addGestureRecognizer(twoFingerTap)

        let hold = UILongPressGestureRecognizer(target: self, action: #selector(handleHold(_:)))
        hold.minimumPressDuration = 0.35
        hold.allowableMovement = .greatestFiniteMagnitude
        hold.delegate = self
        addGestureRecognizer(hold)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipeDown.direction = .down
        swipeDown.numberOfTouchesRequired = 1
        swipeDown.delegate = self
        addGestureRecognizer(swipeDown)
    }

    // MARK: - Taps

    @objc private func handleSingleTap() {
        handler?.onSingleTap()
    }

    @objc private func handleTwoFingerTap() {
        handler?.onTwoFingerTap()
    }

    @objc private func handleSwipeDown() {
        handler?.onSwipeDown()
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        let zone = SeekMath.tapZone(x: point.x, width: bounds.width)
        handler?.onDoubleTap(zone, point.x)
    }

    // MARK: - Hold to fast forward

    @objc private func handleHold(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            holdGestureActive = true
            holdStartPoint = recognizer.location(in: self)
            handler?.onHoldBegan()
        case .changed:
            guard holdGestureActive else { return }
            // Vertical travel since the press began decides the speed: drag up to
            // climb, drag back down to drop.
            let offset = recognizer.location(in: self).y - holdStartPoint.y
            handler?.onHoldChanged(offset)
        case .ended, .cancelled, .failed:
            guard holdGestureActive else { return }
            holdGestureActive = false
            handler?.onHoldEnded()
        default:
            break
        }
    }

    // MARK: - Pan: scrub left and right, brightness or volume up and down

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self)
        switch recognizer.state {
        case .began:
            lastVerticalTranslation = 0
            dragStartedOnLeftHalf = recognizer.location(in: self).x < bounds.width / 2
        case .changed:
            if !isScrubbing && !isAdjustingVertically {
                if abs(translation.x) > abs(translation.y) * 1.2 {
                    isScrubbing = true
                    handler?.onScrubBegan()
                } else if abs(translation.y) > 12 {
                    isAdjustingVertically = true
                    handler?.onVerticalDragBegan(dragStartedOnLeftHalf)
                }
            }
            if isScrubbing {
                handler?.onScrubChanged(translation.x, bounds.width)
            } else if isAdjustingVertically {
                let delta = translation.y - lastVerticalTranslation
                lastVerticalTranslation = translation.y
                handler?.onVerticalDragChanged(delta, dragStartedOnLeftHalf)
            }
        case .ended, .cancelled, .failed:
            if isScrubbing {
                handler?.onScrubEnded()
            }
            if isAdjustingVertically {
                handler?.onVerticalDragEnded(dragStartedOnLeftHalf)
            }
            isScrubbing = false
            isAdjustingVertically = false
            lastVerticalTranslation = 0
        default:
            break
        }
    }

    // MARK: - Pinch

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .changed:
            handler?.onPinchChanged(recognizer.scale)
            recognizer.scale = 1
        case .ended, .cancelled, .failed:
            handler?.onPinchEnded()
        default:
            break
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        // A hold that turns into a drag has to keep working, so let the pan and
        // the press coexist.
        let pair = [gestureRecognizer, other]
        let hasHold = pair.contains { $0 is UILongPressGestureRecognizer }
        let hasPinch = pair.contains { $0 is UIPinchGestureRecognizer }
        return hasHold || hasPinch
    }
}
