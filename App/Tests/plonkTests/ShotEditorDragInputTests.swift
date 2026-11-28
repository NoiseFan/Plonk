import AppKit
import Testing
@testable import plonk

@MainActor
struct ShotEditorDragInputTests {
    @Test(arguments: [Annotation.Kind.line, .arrow])
    func lineGestureStartsInsideTheImageAndKeepsTheMouseDownStyle(_ kind: Annotation.Kind) throws {
        _ = NSApplication.shared
        let annotation = ShotAnnotationState(defaults: .init())
        annotation.tool = kind
        let frame = CGRect(x: 0, y: 50, width: 400, height: 200)
        var history = AnnotationHistory()
        let input = ShotEditorDragInput.InputView(.init(
            imageFrame: frame, minimumDragDistance: 0,
            onBegin: {
                annotation.beginMark(in: &history, at: ImageFit.unitPoint($0, in: frame), viewWidth: frame.width)
            },
            onDrag: { history.drag(to: ImageFit.unitPoint($0, in: frame)) },
            onEnd: { history.end(at: ImageFit.unitPoint($0, in: frame)) }
        ))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 400, height: 300),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.contentView = input

        func mouse(_ type: NSEvent.EventType, at point: CGPoint) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: input.convert(point, to: nil), modifierFlags: [],
                                             timestamp: 0, windowNumber: window.windowNumber, context: nil,
                                             eventNumber: 0, clickCount: 1, pressure: 1))
        }

        let start = CGPoint(x: 100, y: 100)
        input.mouseDown(with: try mouse(.leftMouseDown, at: CGPoint(x: 100, y: 20)))
        input.mouseDragged(with: try mouse(.leftMouseDragged, at: start))
        input.mouseUp(with: try mouse(.leftMouseUp, at: start))
        #expect(history.annotations.isEmpty)

        input.mouseDown(with: try mouse(.leftMouseDown, at: start))
        let keyPath = AnnotationStyles.path(for: kind)
        annotation.styles[keyPath: keyPath] = .init(width: 8, color: .blue)
        let bend = CGPoint(x: 100.5, y: 100)
        input.mouseDragged(with: try mouse(.leftMouseDragged, at: bend))
        #expect(history.live?.points.last == ImageFit.unitPoint(bend, in: frame))
        let end = CGPoint(x: 300, y: 260)
        input.mouseUp(with: try mouse(.leftMouseUp, at: end))
        let mark = try #require(history.annotations.first)
        #expect(mark.points == [ImageFit.unitPoint(start, in: frame), ImageFit.unitPoint(end, in: frame)])
        #expect(mark.colorIndex == AnnotationColor.red.index)
        #expect(mark.width * frame.width == 4)
        #expect(history.live == nil)
    }
}
