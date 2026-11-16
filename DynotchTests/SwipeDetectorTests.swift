@testable import Dynotch
import Testing

struct SwipeDetectorTests {
    @Test func fingersLeftMeansNext() {
        var detector = SwipeDetector()
        #expect(detector.handle(phase: .began, isMomentum: false, fingerDeltaX: -10, deltaY: 0) == nil)
        #expect(detector.handle(phase: .changed, isMomentum: false, fingerDeltaX: -25, deltaY: 1) == .next)
    }

    @Test func fingersRightMeansPrevious() {
        var detector = SwipeDetector()
        _ = detector.handle(phase: .began, isMomentum: false, fingerDeltaX: 12, deltaY: 0)
        #expect(detector.handle(phase: .changed, isMomentum: false, fingerDeltaX: 20, deltaY: 0) == .previous)
    }

    @Test func firesOnlyOncePerGesture() {
        var detector = SwipeDetector()
        _ = detector.handle(phase: .began, isMomentum: false, fingerDeltaX: -40, deltaY: 0)
        #expect(detector.handle(phase: .changed, isMomentum: false, fingerDeltaX: -40, deltaY: 0) == nil)
        _ = detector.handle(phase: .ended, isMomentum: false, fingerDeltaX: 0, deltaY: 0)
        #expect(detector.handle(phase: .began, isMomentum: false, fingerDeltaX: -40, deltaY: 0) == .next)
    }

    @Test func verticalScrollIsIgnored() {
        var detector = SwipeDetector()
        _ = detector.handle(phase: .began, isMomentum: false, fingerDeltaX: 5, deltaY: 30)
        #expect(detector.handle(phase: .changed, isMomentum: false, fingerDeltaX: 30, deltaY: 60) == nil)
        #expect(!detector.isHorizontalGesture)
    }

    @Test func momentumAndWheelEventsAreIgnored() {
        var detector = SwipeDetector()
        #expect(detector.handle(phase: .none, isMomentum: false, fingerDeltaX: -100, deltaY: 0) == nil)
        #expect(detector.handle(phase: .changed, isMomentum: true, fingerDeltaX: -100, deltaY: 0) == nil)
    }
}

struct VerticalSwipeTests {
    @Test func swipeUpFiresOnce() {
        var swipe = VerticalSwipe()
        let result1 = swipe.handle(phase: .began, fingerUp: 10, deltaX: 0)
        #expect(!result1)
        let result2 = swipe.handle(phase: .changed, fingerUp: 25, deltaX: 2)
        #expect(result2)
        let result3 = swipe.handle(phase: .changed, fingerUp: 40, deltaX: 0)
        #expect(!result3)
        let result4 = swipe.handle(phase: .ended, fingerUp: 0, deltaX: 0)
        #expect(!result4)
    }

    @Test func downOrSidewaysDoesNothing() {
        var swipe = VerticalSwipe()
        _ = swipe.handle(phase: .began, fingerUp: -10, deltaX: 0)
        let result5 = swipe.handle(phase: .changed, fingerUp: -40, deltaX: 0)
        #expect(!result5)
        var sideways = VerticalSwipe()
        _ = sideways.handle(phase: .began, fingerUp: 5, deltaX: 30)
        let result6 = sideways.handle(phase: .changed, fingerUp: 30, deltaX: 40)
        #expect(!result6)
        let result7 = sideways.handle(phase: .none, fingerUp: 100, deltaX: 0)
        #expect(!result7)
    }
}
