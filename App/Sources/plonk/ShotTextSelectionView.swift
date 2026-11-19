import AppKit
import Carbon.HIToolbox

final class ShotTextSelectionView: NSView {
    private var selection: ShotTextSelection
    private let onCopy: () -> Void

    init(frame: CGRect, selection: ShotTextSelection, onCopy: @escaping () -> Void) {
        self.selection = selection
        self.onCopy = onCopy
        super.init(frame: frame)
        setAccessibilityLabel(String(localized: .shotText))
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .iBeam) }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        select(with: event, extending: event.modifierFlags.contains(.shift))
    }

    override func mouseDragged(with event: NSEvent) {
        select(with: event, extending: true)
    }

    private func select(with event: NSEvent, extending: Bool) {
        let point = ImageFit.unitPoint(convert(event.locationInWindow, from: nil), in: bounds)
        guard let index = selection.nearest(to: point) else { return }
        selection.select(index, extending: extending)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let key = Int(event.keyCode)
        if (flags.isEmpty || flags == .shift), key == kVK_LeftArrow || key == kVK_RightArrow {
            selection.move(by: key == kVK_LeftArrow ? -1 : 1, extending: flags == .shift)
            needsDisplay = true
        } else {
            super.keyDown(with: event)
        }
    }

    @objc func copy(_ sender: Any?) {
        let text = selection.text
        guard !text.isEmpty else { return }
        NSPasteboard.general.replaceContents(with: text)
        onCopy()
    }

    override func selectAll(_ sender: Any?) {
        selection.selectAll()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.selectedTextBackgroundColor.withAlphaComponent(0.5).setFill()
        for glyph in selection.selected {
            guard let rect = glyph.box else { continue }
            CGRect(x: rect.minX * bounds.width, y: rect.minY * bounds.height,
                   width: rect.width * bounds.width, height: rect.height * bounds.height).fill()
        }
    }
}
