import CoreGraphics
import Testing
@testable import plonk

struct QuickShotPressTests {
    @Test func pressOutsideStartsASelectionWhenNothingIsMarked() {
        #expect(QuickShotPress(handle: .zero, insideSelection: false, drawing: true, marksExist: false) == .select)
    }

    @Test func pressOutsideKeepsExistingMarks() {
        #expect(QuickShotPress(handle: .zero, insideSelection: false, drawing: true, marksExist: true) == .ignore)
        #expect(QuickShotPress(handle: .zero, insideSelection: false, drawing: false, marksExist: true) == .ignore)
    }

    @Test func handlesAndInteriorStillWorkWithMarks() {
        let edge = CGPoint(x: 1, y: 0)
        #expect(QuickShotPress(handle: edge, insideSelection: false, drawing: true, marksExist: true)
            == .adjust(handle: edge))
        #expect(QuickShotPress(handle: .zero, insideSelection: true, drawing: false, marksExist: true)
            == .adjust(handle: .zero))
        #expect(QuickShotPress(handle: .zero, insideSelection: true, drawing: true, marksExist: true) == .mark)
    }

    @Test func pressInsideAFullDisplaySelectionDrawsAFreshRegion() {
        #expect(QuickShotPress(handle: .zero, insideSelection: true, coversDisplay: true, drawing: false,
                               marksExist: false) == .select)
    }

    @Test func fullDisplaySelectionKeepsMarksAndDrawingTools() {
        #expect(QuickShotPress(handle: .zero, insideSelection: true, coversDisplay: true, drawing: false,
                               marksExist: true) == .adjust(handle: .zero))
        #expect(QuickShotPress(handle: .zero, insideSelection: true, coversDisplay: true, drawing: true,
                               marksExist: false) == .mark)
    }

    @Test func handlesOfAFullDisplaySelectionStillResize() {
        let corner = CGPoint(x: 1, y: 1)
        #expect(QuickShotPress(handle: corner, insideSelection: true, coversDisplay: true, drawing: false,
                               marksExist: false) == .adjust(handle: corner))
    }
}
