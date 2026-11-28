import AppKit
import Testing
@testable import plonk

@MainActor
struct QuickShotRegionTests {
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

    @Test func openingTheEditorPassesTheLineCropAndItsRedoHistory() throws {
        _ = NSApplication.shared
        let frame = CGRect(x: 0, y: 0, width: 800, height: 500)
        let context = try #require(CGContext(
            data: nil, width: 800, height: 500, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(frame)
        let bitmap = ShotBitmap(image: try #require(context.makeImage()), displaySize: frame.size)
        let annotation = ShotAnnotationState(defaults: .init(line: .init(width: 8, color: .red)))
        let canvas = QuickShotCanvas(bitmap: bitmap, size: frame.size, safeArea: frame, fixed: false,
                                     annotation: annotation)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = canvas

        func gesture(from start: CGPoint, to end: CGPoint) throws {
            canvas.mouseDown(with: try mouse(.leftMouseDown, at: start, in: canvas, window: window))
            canvas.mouseDragged(with: try mouse(.leftMouseDragged, at: end, in: canvas, window: window))
            canvas.mouseUp(with: try mouse(.leftMouseUp, at: end, in: canvas, window: window))
        }

        try gesture(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 380, y: 300))
        let toolbar = try #require(canvas.subviews.compactMap { $0 as? QuickShotToolbar }.first)
        let buttons = toolbar.subviews.compactMap { $0 as? QuickShotButton }
        let lineTitle = String(localized: Annotation.Kind.line.title)
        let lineIndex = try #require(buttons.firstIndex { $0.accessibilityLabel() == lineTitle })
        let arrowIndex = try #require(buttons.firstIndex { $0.accessibilityLabel() == String(localized: .toolArrow) })
        #expect(lineIndex + 1 == arrowIndex)
        #expect(buttons[lineIndex].toolTip == lineTitle)
        #expect(buttons[lineIndex].image != nil)
        buttons[lineIndex].performClick(nil)
        #expect(buttons[lineIndex].isSelectedTool == true)

        try gesture(from: CGPoint(x: 150, y: 150), to: CGPoint(x: 430, y: 150))
        annotation.styles.line = .init(width: 12, color: .blue)
        try gesture(from: CGPoint(x: 170, y: 220), to: CGPoint(x: 320, y: 220))
        canvas.handle(.undo)

        var output: ShotCrop?
        canvas.onOutput = { action, crop in
            if case .editor = action { output = crop }
        }
        let editor = try #require(buttons.first { $0.accessibilityLabel() == String(localized: .shotAfterEditor) })
        editor.performClick(nil)

        let crop = try #require(output)
        #expect(crop.history.annotations.map(\.kind) == [.line])
        #expect(crop.history.canRedo)
        let rendered = try #require(crop.rendered())
        let png = try #require(ScreenshotManager.pngData(from: rendered))
        let rep = try #require(NSBitmapImageRep(data: png))
        #expect(rep.pixelsWide == 280 && rep.pixelsHigh == 200)
        for x in [47, 279] {
            let pixel = try #require(rep.colorAt(x: x, y: 50)?.usingColorSpace(.sRGB))
            #expect(pixel.redComponent > 0.8 && pixel.greenComponent < 0.4)
        }
        let outsideCap = try #require(rep.colorAt(x: 46, y: 46)?.usingColorSpace(.sRGB))
        #expect(outsideCap.greenComponent > 0.95)

        var history = crop.history
        history.redo()
        let restored = try #require(history.annotations.last)
        #expect(restored.kind == .line)
        #expect(restored.colorIndex == AnnotationColor.blue.index)
        #expect(abs(restored.width * crop.image.size.width - 12) < 0.0001)
        let editorImage = try #require(crop.image.annotated(with: history.annotations))
        let editorPNG = try #require(ScreenshotManager.pngData(from: editorImage))
        let editorRep = try #require(NSBitmapImageRep(data: editorPNG))
        let pixel = try #require(editorRep.colorAt(x: 100, y: 120)?.usingColorSpace(.sRGB))
        #expect(pixel.blueComponent > 0.8 && pixel.redComponent < 0.4)
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
