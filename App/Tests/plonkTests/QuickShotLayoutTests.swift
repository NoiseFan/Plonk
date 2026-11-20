import CoreGraphics
import Testing
@testable import plonk

struct QuickShotLayoutTests {
    private let dividers = (0..<17).map { $0 == 6 || $0 == 9 }

    @Test func desktopToolbarMatchesPrototypeSpacing() {
        let (size, frames) = QuickShotLayout.toolbar(dividers: dividers, availableWidth: 1000, compact: false)

        #expect(size == CGSize(width: 592, height: 42))
        #expect(frames[0] == CGRect(x: 8, y: 5, width: 34, height: 32))
        #expect(frames[6] == CGRect(x: 230, y: 5, width: 9, height: 32))
        #expect(frames[9] == CGRect(x: 316, y: 5, width: 9, height: 32))
        #expect(frames[16] == CGRect(x: 550, y: 5, width: 34, height: 32))
    }

    @Test func compactToolbarWrapsAndKeepsItsButtonsInBounds() {
        let (size, frames) = QuickShotLayout.toolbar(dividers: dividers, availableWidth: 486, compact: true)

        #expect(size == CGSize(width: 486, height: 72))
        #expect(frames[0] == CGRect(x: 8, y: 5, width: 30, height: 30))
        #expect(frames.last?.minY == 37)
        #expect(frames.allSatisfy { CGRect(origin: .zero, size: size).contains($0) })
    }

    @Test func controlsAlignToLeftEdgeWithPrototypeOffsets() {
        let selection = CGRect(x: 180, y: 100, width: 700, height: 400)
        let frames = QuickShotLayout.place(dimensions: CGSize(width: 144, height: 29),
                                          toolbar: CGSize(width: 592, height: 42), selection: selection,
                                          area: CGRect(x: 0, y: 0, width: 1200, height: 800))

        #expect(frames.dimensions == CGRect(x: 180, y: 61, width: 144, height: 29))
        #expect(frames.toolbar == CGRect(x: 180, y: 516, width: 592, height: 42))
    }

    @Test func selectionAtBottomRightKeepsBothControlsReachable() {
        let area = CGRect(x: 0, y: 25, width: 1200, height: 750)
        let selection = CGRect(x: 870, y: 720, width: 330, height: 80)
        let frames = QuickShotLayout.place(dimensions: CGSize(width: 144, height: 29),
                                          toolbar: CGSize(width: 592, height: 42), selection: selection, area: area)

        #expect(area.contains(frames.toolbar))
        #expect(area.contains(frames.dimensions))
        #expect(frames.toolbar.maxY < frames.dimensions.minY)
    }
}
