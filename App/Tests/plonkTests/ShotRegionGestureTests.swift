import CoreGraphics
import Testing
@testable import plonk

struct ShotRegionGestureTests {
    @Test func aPressWithoutMovementIsAClick() {
        var desktop = ShotRegionGesture(start: CGPoint(x: 10, y: 10), startsOnWindow: false)
        desktop.update(to: CGPoint(x: 10, y: 10))
        #expect(!desktop.isDragging)
        var window = ShotRegionGesture(start: CGPoint(x: 10, y: 10), startsOnWindow: true)
        window.update(to: CGPoint(x: 10, y: 10))
        #expect(!window.isDragging)
    }

    @Test func anyMovementOffAWindowStartsADrag() {
        var gesture = ShotRegionGesture(start: CGPoint(x: 10, y: 10), startsOnWindow: false)
        gesture.update(to: CGPoint(x: 10.5, y: 10))
        #expect(gesture.isDragging)
    }

    @Test func onAWindowADragNeedsFourPoints() {
        var gesture = ShotRegionGesture(start: CGPoint(x: 10, y: 10), startsOnWindow: true)
        gesture.update(to: CGPoint(x: 13, y: 12))
        #expect(!gesture.isDragging)
        gesture.update(to: CGPoint(x: 14, y: 10))
        #expect(gesture.isDragging)
    }

    @Test func dragDistanceOnAWindowIsMeasuredFromTheStart() {
        var gesture = ShotRegionGesture(start: CGPoint(x: 10, y: 10), startsOnWindow: true)
        gesture.update(to: CGPoint(x: 13, y: 10))
        gesture.update(to: CGPoint(x: 10, y: 13))
        #expect(!gesture.isDragging)
        gesture.update(to: CGPoint(x: 13, y: 14))
        #expect(gesture.isDragging)
    }

    @Test func endTracksThePointerAndADragNeverReverts() {
        var gesture = ShotRegionGesture(start: CGPoint(x: 10, y: 10), startsOnWindow: true)
        #expect(gesture.end == gesture.start)
        gesture.update(to: CGPoint(x: 40, y: 30))
        #expect(gesture.end == CGPoint(x: 40, y: 30))
        gesture.update(to: CGPoint(x: 11, y: 10))
        #expect(gesture.isDragging)
        #expect(gesture.end == CGPoint(x: 11, y: 10))
        #expect(gesture.start == CGPoint(x: 10, y: 10))
    }
}
