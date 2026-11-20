import AppKit
import Testing
@testable import plonk

struct QuickShotDimensionsTests {
    @MainActor
    @Test func firstClickSelectsEntirePixelValue() throws {
        _ = NSApplication.shared
        let dimensions = QuickShotDimensions()
        let window = NSWindow(contentRect: dimensions.frame, styleMask: .borderless,
                              backing: .buffered, defer: false)
        window.contentView = dimensions
        dimensions.update(width: 920, height: 600)
        let widthCenter = dimensions.convert(CGPoint(x: 27, y: 14), to: nil)

        #expect(dimensions.selectField(at: widthCenter))

        let editor = try #require(window.firstResponder as? NSTextView)
        #expect(editor.string == "920")
        #expect(editor.selectedRange() == NSRange(location: 0, length: 3))
    }
}
