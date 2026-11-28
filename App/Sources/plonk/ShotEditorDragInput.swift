import SwiftUI

struct ShotEditorDragInput: NSViewRepresentable {
    let imageFrame: CGRect
    let minimumDragDistance: CGFloat
    let onBegin: (CGPoint) -> Void
    let onDrag: (CGPoint) -> Void
    let onEnd: (CGPoint) -> Void

    func makeNSView(context: Context) -> InputView { InputView(self) }

    func updateNSView(_ view: InputView, context: Context) { view.input = self }

    final class InputView: NSView {
        var input: ShotEditorDragInput
        private var gesture: (start: CGPoint, minimumDistance: CGFloat)?
        private var dragging = false

        init(_ input: ShotEditorDragInput) {
            self.input = input
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }
        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            let point = convert(event.locationInWindow, from: nil)
            guard input.imageFrame.contains(point) else { return }
            gesture = (point, input.minimumDragDistance)
            input.onBegin(point)
        }

        override func mouseDragged(with event: NSEvent) {
            guard let gesture else { return }
            let point = convert(event.locationInWindow, from: nil)
            let distance = hypot(point.x - gesture.start.x, point.y - gesture.start.y)
            guard dragging || distance >= gesture.minimumDistance else { return }
            dragging = true
            input.onDrag(point)
        }

        override func mouseUp(with event: NSEvent) {
            guard let gesture else { return }
            let point = dragging || gesture.minimumDistance == 0 ? convert(event.locationInWindow, from: nil)
                : gesture.start
            self.gesture = nil
            dragging = false
            input.onEnd(point)
        }
    }
}
