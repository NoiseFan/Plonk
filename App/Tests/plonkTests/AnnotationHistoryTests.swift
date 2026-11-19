import AppKit
import Testing
@testable import plonk

struct AnnotationHistoryTests {
    @Test func newMarkClearsRedoHistory() {
        var history = AnnotationHistory()
        history.addStep(at: CGPoint(x: 0.2, y: 0.2), color: 0, diameter: 0.025)
        history.undo()
        #expect(history.canRedo)
        history.addStep(at: CGPoint(x: 0.7, y: 0.7), color: 0, diameter: 0.025)
        #expect(!history.canRedo)
        #expect(history.annotations.count == 1)
    }

    @Test func stepEditsPreserveNumbersAcrossCropsAndUndo() throws {
        var history = AnnotationHistory()
        let point = CGPoint(x: 0.5, y: 0.5)
        history.addStep(at: point, color: 0, diameter: 0.025)
        let middle = history.addStep(at: point, color: 0, diameter: 0.025)
        history.addStep(at: point, color: 0, diameter: 0.025)
        var moved = middle
        moved.points = [CGPoint(x: 0.75, y: 0.5)]
        history.editStep(middle, replacement: moved)
        history.editStep(moved, replacement: nil)
        #expect(history.annotations.compactMap(\.stepNumber) == [1, 3])

        var cropped = history.rebased(to: CGRect(x: 0.25, y: 0, width: 0.5, height: 1))
        cropped.undo()
        #expect(cropped.annotations[1].points == [CGPoint(x: 1, y: 0.5)])
        cropped.undo()
        #expect(cropped.annotations[1].points == [point])
        cropped.redo()
        cropped.redo()
        #expect(cropped.annotations.compactMap(\.stepNumber) == [1, 3])
        let next = cropped.addStep(at: point, color: 0, diameter: 0.05)
        #expect(next.stepNumber == 4)
    }

    @Test func handoffPreservesThePositionAndSizeOfMarksOutsideTheCrop() throws {
        var history = AnnotationHistory()
        history.begin(.arrow, at: CGPoint(x: 0.125, y: 0.125), color: 0, width: 0.002)
        history.drag(to: CGPoint(x: 0.5, y: 0.5))
        history.end()
        let moved = history.rebased(to: CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.25))
        let arrow = try #require(moved.annotations.first)
        #expect(arrow.points == [CGPoint(x: -0.25, y: -0.5), CGPoint(x: 0.5, y: 1)])
        #expect(arrow.width == 0.004)
        #expect(arrow.arrowHead == 0.024)
    }

    @Test func textAndRedoSurviveHandoff() throws {
        var history = AnnotationHistory()
        history.append(Annotation(kind: .text, points: [CGPoint(x: 0.5, y: 0.5)], colorIndex: 2,
                                  width: 0.025, text: "First line\n第二行"))
        history.undo()
        var moved = history.rebased(to: CGRect(x: 0.25, y: 0, width: 0.5, height: 1))
        moved.redo()
        let text = try #require(moved.annotations.first)
        #expect(text.points == [CGPoint(x: 0.5, y: 0.5)])
        #expect(text.width == 0.05)
        #expect(text.text == "First line\n第二行")
        moved.undo()
        #expect(moved.annotations.isEmpty)
    }

    @MainActor
    @Test func annotatedPNGPreservesExactDimensions() throws {
        let context = try #require(CGContext(
            data: nil, width: 800, height: 600, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 800, height: 600))
        let source = NSImage(cgImage: try #require(context.makeImage()), size: CGSize(width: 400, height: 300))
        let text = Annotation(kind: .text, points: [CGPoint(x: 0.25, y: 0.25)], colorIndex: 0,
                              width: 0.04, text: "Plonk\n截图")
        let rendered = try #require(source.annotated(with: [text]))
        let data = try #require(ScreenshotManager.pngData(from: rendered))
        let png = try #require(NSBitmapImageRep(data: data))
        #expect(png.pixelsWide == 800)
        #expect(png.pixelsHigh == 600)
        #expect(data != ScreenshotManager.pngData(from: source))
    }
}
