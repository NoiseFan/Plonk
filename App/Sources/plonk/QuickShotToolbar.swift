import AppKit

final class QuickShotToolbar: NSView {
    private var items: [NSView] = []
    private var dividers: [Bool] = []
    private var choices: [(QuickShotButton, Annotation.Kind?)] = []
    private let undo: QuickShotButton
    private let redo: QuickShotButton

    init(canvas: QuickShotCanvas) {
        undo = QuickShotButton(.undo, title: .shotEditorUndo) { [weak canvas] _ in canvas?.editHistory(redo: false) }
        redo = QuickShotButton(.redo, title: .shotEditorRedo) { [weak canvas] _ in canvas?.editHistory(redo: true) }
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(srgbRed: 41 / 255, green: 45 / 255, blue: 52 / 255, alpha: 1).cgColor
        layer?.cornerRadius = 24
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.white.withAlphaComponent(32 / 255).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.4
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -5)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(String(localized: .shotAfterQuickActions))

        let tools: [(QuickShotIcon, Annotation.Kind?, LocalizedStringResource)] = [
            (.move, nil, .shotSelectionMove),
            (.rectangle, .rectangle, .toolRectangle),
            (.ellipse, .ellipse, .toolEllipse),
            (.arrow, .arrow, .toolArrow),
            (.pen, .pen, .toolPen),
            (.text, .text, .toolText),
        ]
        for (icon, kind, label) in tools {
            let button = QuickShotButton(icon, title: label, toggle: true) { [weak canvas] _ in
                guard let canvas else { return }
                canvas.selectTool(canvas.tool == kind ? nil : kind)
            }
            choices.append((button, kind))
            addItem(button)
        }
        addDivider()
        addItem(undo)
        addItem(redo)
        addDivider()
        addItem(QuickShotButton(.cancel, title: .commonCancel) { [weak canvas] _ in canvas?.onCancel?() })
        let actions: [(QuickShotIcon, LocalizedStringResource, QuickShotAction)] = [
            (.preview, .shotOpenPreview, .preview),
            (.ocr, .shotRecognizeAndCopyText, .recognizeText),
            (.editor, .shotAfterEditor, .editor),
            (.folder, .shotEditorSaveToFolder, .save()),
            (.save, .shotEditorSaveAs, .saveAs),
            (.copy, .shotEditorCopy, .copy),
        ]
        for (icon, label, action) in actions {
            addItem(QuickShotButton(icon, title: label) { [weak canvas] _ in canvas?.perform(action) })
        }
        update(tool: canvas.tool)
        update(history: canvas.history)
        canvas.onHistoryChanged = { [weak self] in self?.update(history: $0) }
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }

    private func addItem(_ item: NSView, divider: Bool = false) {
        addSubview(item)
        items.append(item)
        dividers.append(divider)
    }

    private func addDivider() {
        let rule = NSView()
        rule.wantsLayer = true
        rule.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.2).cgColor
        addItem(rule, divider: true)
    }

    func sizeToFit(availableWidth: CGFloat, compact: Bool) -> CGSize {
        let (size, frames) = QuickShotLayout.toolbar(dividers: dividers, availableWidth: availableWidth, compact: compact)
        for (item, frame) in zip(items, frames) {
            item.frame = item is QuickShotButton ? frame
                : CGRect(x: frame.minX + 4, y: frame.midY - 7.5, width: 1, height: 15)
        }
        return size
    }

    func update(tool: Annotation.Kind?) {
        for (button, kind) in choices {
            button.state = tool == kind ? .on : .off
        }
    }

    private func update(history: AnnotationHistory) {
        undo.isEnabled = history.canUndo
        redo.isEnabled = history.canRedo
        window?.invalidateCursorRects(for: undo)
        window?.invalidateCursorRects(for: redo)
    }
}
