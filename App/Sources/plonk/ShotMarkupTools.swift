import AppKit

final class ShotMarkupTools: NSObject {
    let stack = NSStackView()
    private let accent: NSColor
    private let kinds: [Annotation.Kind]
    private var choiceButtons: [NSButton] = []
    private let undoButton = NSButton()
    private let redoButton = NSButton()
    private weak var canvas: ShotMarkupCanvas?

    init(canvas: ShotMarkupCanvas, kinds: [Annotation.Kind], accent: NSColor) {
        self.accent = accent
        self.kinds = kinds
        self.canvas = canvas
        super.init()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 3
        for (index, kind) in kinds.enumerated() {
            addTool(symbol: kind.symbol, title: kind.title, index: index)
        }
        if let last = choiceButtons.last { stack.setCustomSpacing(10, after: last) }
        Self.configure(undoButton, symbol: "arrow.uturn.backward",
                       title: .shotEditorUndo, target: self, action: #selector(undo))
        Self.configure(redoButton, symbol: "arrow.uturn.forward",
                       title: .shotEditorRedo, target: self, action: #selector(redo))
        stack.addArrangedSubview(undoButton)
        stack.addArrangedSubview(redoButton)
        canvas.onHistoryChanged = { [weak self] in self?.refreshHistory($0) }
        refreshHistory(canvas.history)
        refreshChoice()
    }

    func select(_ kind: Annotation.Kind?) {
        guard let canvas, canvas.commitText() else { return }
        canvas.tool = kind
        canvas.window?.makeFirstResponder(canvas)
        canvas.window?.invalidateCursorRects(for: canvas)
        refreshChoice()
    }

    private func addTool(symbol: String, title: LocalizedStringResource, index: Int) {
        let button = NSButton()
        Self.configure(button, symbol: symbol, title: title, target: self, action: #selector(choose))
        button.setButtonType(.toggle)
        button.tag = index
        button.wantsLayer = true
        button.layer?.cornerRadius = 6
        choiceButtons.append(button)
        stack.addArrangedSubview(button)
    }

    private func refreshChoice() {
        for button in choiceButtons {
            let kind = kinds[button.tag]
            let active = canvas?.tool == kind
            button.state = active ? .on : .off
            button.layer?.backgroundColor = active ? accent.withAlphaComponent(0.18).cgColor : nil
        }
    }

    private func refreshHistory(_ history: AnnotationHistory) {
        undoButton.isEnabled = history.canUndo
        redoButton.isEnabled = history.canRedo
    }

    @objc private func choose(_ button: NSButton) {
        select(kinds[button.tag])
    }
    @objc private func undo() {
        guard let canvas, canvas.commitText() else { return }
        canvas.undoMark()
    }
    @objc private func redo() {
        guard let canvas, canvas.commitText() else { return }
        canvas.redoMark()
    }

    static func configure(_ button: NSButton, symbol: String, title: LocalizedStringResource,
                          target: AnyObject, action: Selector) {
        let label = String(localized: title)
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)?
            .withSymbolConfiguration(.init(pointSize: 15, weight: .medium))
        button.imagePosition = .imageOnly
        button.bezelStyle = .regularSquare
        button.controlSize = .small
        button.isBordered = false
        button.toolTip = label
        button.setAccessibilityLabel(label)
        button.target = target
        button.action = action
        button.widthAnchor.constraint(equalToConstant: 24).isActive = true
        button.heightAnchor.constraint(equalToConstant: 24).isActive = true
    }
}
