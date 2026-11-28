import AppKit
import Testing
@testable import plonk

@MainActor
struct QuickShotRegionTests {
    @Test func regionFrameFollowsTheAreaBeingDrawn() throws {
        _ = NSApplication.shared
        let context = try #require(CGContext(
            data: nil, width: 800, height: 800, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let size = CGSize(width: 400, height: 400)
        let bitmap = ShotBitmap(image: try #require(context.makeImage()), displaySize: size)
        let frame = CGRect(origin: .zero, size: size)
        let canvas = QuickShotCanvas(bitmap: bitmap, size: size, safeArea: frame, fixed: false)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = canvas

        func event(_ type: NSEvent.EventType, _ x: CGFloat, _ y: CGFloat) throws -> NSEvent {
            try mouse(type, at: CGPoint(x: x, y: y), in: canvas, window: window)
        }

        #expect(canvas.regionFrame == nil && !canvas.isDraggingRegionBoundary)
        canvas.mouseDown(with: try event(.leftMouseDown, 100, 100))
        #expect(canvas.isDraggingRegionBoundary && canvas.regionFrame == nil)
        canvas.mouseDragged(with: try event(.leftMouseDragged, 160, 100))
        #expect(canvas.regionFrame == nil)

        canvas.mouseDragged(with: try event(.leftMouseDragged, 240, 240))
        #expect(canvas.regionFrame != nil)
        canvas.mouseDragged(with: try event(.leftMouseDragged, 100, 100))
        #expect(canvas.regionFrame == nil)
        canvas.mouseUp(with: try event(.leftMouseUp, 240, 240))
        #expect(canvas.regionFrame != nil && !canvas.isDraggingRegionBoundary)

        canvas.mouseDown(with: try event(.leftMouseDown, 240, 170))
        #expect(canvas.isDraggingRegionBoundary)
        canvas.mouseUp(with: try event(.leftMouseUp, 260, 170))
        #expect(canvas.regionFrame?.maxX == 260 && !canvas.isDraggingRegionBoundary)
        canvas.clearSelection()
        #expect(canvas.regionFrame == nil)
        canvas.select()
        #expect(canvas.regionFrame == frame)
    }

    @Test func aRestoredRegionIsCutFromTheCurrentBitmap() throws {
        _ = NSApplication.shared
        let context = try #require(CGContext(
            data: nil, width: 1600, height: 1000, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1000))
        let bitmap = ShotBitmap(image: try #require(context.makeImage()), displaySize: CGSize(width: 800, height: 500))
        let frame = CGRect(origin: .zero, size: bitmap.displaySize)
        let canvas = QuickShotCanvas(bitmap: bitmap, size: frame.size, safeArea: frame, fixed: false)
        let rect = CGRect(x: 140, y: 200, width: 360, height: 280)

        canvas.select(rect)
        let backdrop = try #require(canvas.subviews.compactMap { $0 as? QuickShotBackdrop }.first)
        let toolbar = try #require(canvas.subviews.compactMap { $0 as? QuickShotToolbar }.first)
        #expect(backdrop.selection == CGRect(x: 70, y: 100, width: 180, height: 140))
        #expect(!toolbar.isHidden && !canvas.isWaitingForSelection)

        var output: ShotCrop?
        canvas.onOutput = { _, crop in output = crop }
        canvas.handle(.save)
        let crop = try #require(output)
        #expect(crop.rect == rect)
        let pixels = try #require(crop.image.representations.first as? NSBitmapImageRep)
        #expect(pixels.colorAt(x: 0, y: 0)?.redComponent == 1)
    }

    @Test func addingATipGrowsTheHintUpwards() {
        let tips = QuickShotTips([.shotSelectDisplayHint, .shotCopyColorHint])
        tips.setFrameOrigin(CGPoint(x: 12, y: 400))
        let bottom = tips.frame.maxY
        tips.setTips([.shotSelectDisplayHint, .shotRestoreRegionHint, .shotCopyColorHint])
        #expect(tips.frame.maxY == bottom)
        #expect(tips.frame.minX == 12)
        #expect(tips.accessibilityLabel()?.contains(String(localized: .shotRestoreRegionHint)) == true)
        #expect(tips.hitTest(.zero) == nil)
    }

    @Test func exactDimensionsAreUsedByTheSavedRetinaCrop() throws {
        _ = NSApplication.shared
        let context = try #require(CGContext(
            data: nil, width: 1600, height: 1000, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let bitmap = ShotBitmap(image: try #require(context.makeImage()), displaySize: CGSize(width: 800, height: 500))
        let frame = CGRect(origin: .zero, size: bitmap.displaySize)
        let canvas = QuickShotCanvas(bitmap: bitmap, size: frame.size, safeArea: frame, fixed: false)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = canvas
        let start = try mouse(.leftMouseDown, at: CGPoint(x: 100, y: 100), in: canvas, window: window)
        let end = try mouse(.leftMouseUp, at: CGPoint(x: 280, y: 260), in: canvas, window: window)
        canvas.mouseDown(with: start)
        canvas.mouseUp(with: end)
        let controls = try #require(canvas.subviews.compactMap { $0 as? QuickShotDimensions }.first)
        #expect(canvas.selectDimension(at: controls.convert(CGPoint(x: 27, y: 14), to: nil)))
        try input("800", command: #selector(NSResponder.insertTab(_:)), in: window)
        try input("600", command: #selector(NSResponder.insertNewline(_:)), in: window)

        var output: ShotCrop?
        canvas.onOutput = { _, crop in output = crop }
        canvas.handle(.save)
        let rendered = try #require(output?.rendered())
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: file) }
        let path = try #require(ScreenshotManager.save(rendered, to: .path(file.path)))
        let png = try #require(NSBitmapImageRep(data: Data(contentsOf: URL(fileURLWithPath: path))))
        #expect(png.pixelsWide == 800)
        #expect(png.pixelsHigh == 600)
    }

    private func mouse(_ type: NSEvent.EventType, at point: CGPoint, in view: NSView, window: NSWindow) throws -> NSEvent {
        try #require(NSEvent.mouseEvent(with: type, location: view.convert(point, to: nil), modifierFlags: [],
                                         timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                         eventNumber: 0, clickCount: 1, pressure: 1))
    }

    private func input(_ text: String, command: Selector, in window: NSWindow) throws {
        let editor = try #require(window.firstResponder as? NSTextView)
        editor.insertText(text, replacementRange: editor.selectedRange())
        editor.doCommand(by: command)
    }
}
