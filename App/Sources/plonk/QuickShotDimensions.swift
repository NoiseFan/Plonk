import AppKit

final class QuickShotDimensions: NSView, NSTextFieldDelegate {
    static let accent = NSColor(srgbRed: 0, green: 119 / 255, blue: 246 / 255, alpha: 1)
    var onResize: ((Int, Bool) -> Void)?
    var onLock: ((Bool) -> Void)?
    var onEndEditing: (() -> Void)?

    private let widthField = QuickShotDimensionField(title: .shotSelectionWidth)
    private let heightField = QuickShotDimensionField(title: .shotSelectionHeight)
    private let pixels = NSTextField(labelWithString: String(localized: .shotSelectionPixels))
    private lazy var lock = QuickShotButton(.unlock, title: .shotSelectionLock, toggle: true, iconSize: 19, radius: 4) {
        [weak self] button in self?.toggleLock(button)
    }
    private var width = 0
    private var height = 0
    private var endingExplicitly = false

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = Self.accent.cgColor
        layer?.cornerRadius = 5
        pixels.font = .systemFont(ofSize: 12)
        pixels.textColor = NSColor.white.withAlphaComponent(0.9)
        widthField.delegate = self
        heightField.delegate = self
        for view in [widthField, lock, heightField, pixels] { addSubview(view) }
        widthField.frame = CGRect(x: 6, y: 3, width: 42, height: 23)
        lock.frame = CGRect(x: 51, y: 3, width: 22, height: 23)
        heightField.frame = CGRect(x: 76, y: 3, width: 42, height: 23)
        let label = pixels.intrinsicContentSize
        pixels.frame = CGRect(x: 121, y: (29 - label.height) / 2, width: label.width.rounded(.up), height: label.height)
        setFrameSize(CGSize(width: pixels.frame.maxX + 9, height: 29))
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }

    func update(width: Int, height: Int) {
        self.width = width
        self.height = height
        if widthField.currentEditor() == nil { widthField.stringValue = String(width) }
        if heightField.currentEditor() == nil { heightField.stringValue = String(height) }
    }

    func resetLock() {
        lock.state = .off
        lock.icon = .unlock
    }

    func selectField(at windowPoint: CGPoint) -> Bool {
        guard !isHidden else { return false }
        let point = convert(windowPoint, from: nil)
        guard let field = [widthField, heightField].first(where: { $0.frame.contains(point) }),
              field.currentEditor() == nil else { return false }
        field.selectText(nil)
        return true
    }

    private func toggleLock(_ button: QuickShotButton) {
        guard commit() else {
            button.state = button.state == .on ? .off : .on
            return
        }
        let locked = button.state == .on
        button.icon = locked ? .lock : .unlock
        onLock?(locked)
    }

    func commit() -> Bool {
        for field in [widthField, heightField] {
            if let editor = field.currentEditor() as? NSTextView {
                return commit(field, editor: editor)
            }
        }
        return true
    }

    private func value(_ text: String) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)), value > 0 else { return nil }
        return value
    }

    private func finishEditing() {
        endingExplicitly = true
        onEndEditing?()
        endingExplicitly = false
    }

    private func commit(_ field: NSControl, editor: NSTextView) -> Bool {
        guard !editor.hasMarkedText() else { return false }
        guard let value = value(editor.string) else {
            HUD.shared.show(.shotSelectionInvalid)
            return false
        }
        finishEditing()
        onResize?(value, field === widthField)
        update(width: width, height: height)
        return true
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard !textView.hasMarkedText() else { return false }
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            _ = commit(control, editor: textView)
            return true
        case #selector(NSResponder.insertTab(_:)), #selector(NSResponder.insertBacktab(_:)):
            guard let window = control.window, commit(control, editor: textView) else { return true }
            if commandSelector == #selector(NSResponder.insertBacktab(_:)) {
                window.selectPreviousKeyView(control)
            } else {
                window.selectNextKeyView(control)
            }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            finishEditing()
            update(width: width, height: height)
            return true
        default: return false
        }
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard !endingExplicitly, let field = notification.object as? NSTextField else { return }
        if let value = value(field.stringValue) { onResize?(value, field === widthField) }
        update(width: width, height: height)
    }
}
