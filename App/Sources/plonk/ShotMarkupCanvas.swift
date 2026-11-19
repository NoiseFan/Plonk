import AppKit

class ShotMarkupCanvas: NSView {
    private(set) var history: AnnotationHistory
    var onHistoryChanged: ((AnnotationHistory) -> Void)?
    var tool: Annotation.Kind? {
        didSet {
            if tool != oldValue {
                selectedStep = nil
                updateMarkup()
            }
        }
    }
    var colorIndex = 0
    var strokePoints: Double = 4

    private let preview = ShotMarkupPreview(rootView: ShotMarkupLayer())
    private var textEntry: ShotTextEntry?
    private var textMark: Annotation?
    private var selectedStep: UUID?
    private var stepDrag: (original: Annotation, anchor: CGPoint, preview: Annotation)?
    var canDeleteStep: Bool { history.annotations.contains { $0.id == selectedStep } }

    init(frame: CGRect, history: AnnotationHistory = AnnotationHistory()) {
        self.history = history
        super.init(frame: frame)
        addSubview(preview)
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    var imageRect: CGRect { bounds }
    var markupClip: CGRect { imageRect }

    override func layout() {
        super.layout()
        updateMarkup()
        if let textEntry, let point = textMark?.points.first {
            textEntry.frame = textFrame(at: point)
        }
    }

    func updateMarkup() {
        preview.frame = bounds
        preview.rootView = ShotMarkupLayer(history: history, imageRect: imageRect, clip: markupClip,
                                          selectedStep: selectedStep, movedStep: stepDrag?.preview)
    }

    @discardableResult
    func beginMark(at point: CGPoint) -> Bool {
        guard let tool, markupClip.contains(point), imageRect.width > 0 else { return false }
        let unit = ImageFit.unitPoint(point, in: imageRect)
        if tool == .text {
            beginText(at: unit)
        } else if tool == .step {
            beginStep(at: unit, location: CGPoint(x: point.x - imageRect.minX, y: point.y - imageRect.minY))
        } else {
            history.begin(tool, at: unit, color: colorIndex, width: strokePoints / imageRect.width)
            updateMarkup()
        }
        return true
    }

    @discardableResult
    func dragMark(to point: CGPoint) -> Bool {
        if var drag = stepDrag, let center = drag.original.points.first {
            let location = CGPoint(x: point.x.clamped(to: markupClip.minX...markupClip.maxX),
                                   y: point.y.clamped(to: markupClip.minY...markupClip.maxY))
            let unit = ImageFit.unitPoint(location, in: imageRect)
            drag.preview.points = [CGPoint(x: center.x + (unit.x - drag.anchor.x),
                                           y: center.y + (unit.y - drag.anchor.y))]
            stepDrag = drag
            updateMarkup()
            return true
        }
        guard history.live != nil else { return false }
        history.drag(to: ImageFit.unitPoint(point, in: imageRect))
        updateMarkup()
        return true
    }

    @discardableResult
    func endMark(at point: CGPoint) -> Bool {
        if stepDrag != nil {
            dragMark(to: point)
            if let drag = stepDrag { history.editStep(drag.original, replacement: drag.preview) }
            stepDrag = nil
            changedHistory()
            return true
        }
        guard let last = history.live?.points.last else { return false }
        if last != ImageFit.unitPoint(point, in: imageRect) { dragMark(to: point) }
        history.end()
        changedHistory()
        return true
    }

    private func beginStep(at unit: CGPoint, location: CGPoint) {
        if let mark = history.annotations.last(where: {
            $0.kind == .step && NSBezierPath(ovalIn: $0.stepRect(in: imageRect.size)).contains(location)
        }) {
            selectedStep = mark.id
            stepDrag = (mark, unit, mark)
            updateMarkup()
        } else {
            let mark = history.addStep(at: unit, color: colorIndex,
                                       diameter: max(24, strokePoints * 6) / imageRect.width)
            selectedStep = mark.id
            changedHistory()
        }
    }

    func deleteStep() {
        guard let mark = history.annotations.first(where: { $0.id == selectedStep }) else { return }
        selectedStep = nil
        history.editStep(mark, replacement: nil)
        changedHistory()
    }

    func undoMark() {
        history.undo()
        changedHistory()
    }

    func redoMark() {
        history.redo()
        changedHistory()
    }

    private func changedHistory() {
        updateMarkup()
        onHistoryChanged?(history)
    }

    private func beginText(at point: CGPoint) {
        let fontSize = max(12, strokePoints * 3 + 6)
        let entry = ShotTextEntry(frame: textFrame(at: point))
        entry.font = .systemFont(ofSize: fontSize)
        entry.drawsBackground = true
        entry.backgroundColor = .textBackgroundColor
        entry.textContainerInset = NSSize(width: 4, height: 4)
        entry.isRichText = false
        entry.isAutomaticQuoteSubstitutionEnabled = false
        entry.allowsUndo = true
        entry.setAccessibilityLabel(String(localized: .toolText))
        entry.onCommit = { [weak self] in self?.commitText() }
        entry.onCancel = { [weak self] in self?.cancelText() }
        textMark = Annotation(kind: .text, points: [point], colorIndex: colorIndex, width: fontSize / imageRect.width)
        textEntry = entry
        addSubview(entry)
        window?.makeFirstResponder(entry)
    }

    private func textFrame(at point: CGPoint) -> CGRect {
        let size = CGSize(width: min(bounds.width, 270), height: min(bounds.height, 88))
        let x = point.x * imageRect.width + imageRect.minX
        let y = point.y * imageRect.height + imageRect.minY
        return CGRect(x: min(x, bounds.maxX - size.width), y: min(y, bounds.maxY - size.height),
                      width: size.width, height: size.height)
    }

    @discardableResult
    func commitText() -> Bool {
        guard let entry = textEntry, var mark = textMark else { return true }
        guard !entry.hasMarkedText() else { return false }
        if !entry.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mark.text = entry.string
            history.append(mark)
        }
        cancelText()
        changedHistory()
        return true
    }

    @discardableResult
    func cancelText() -> Bool {
        guard let textEntry else { return false }
        if window?.firstResponder === textEntry { window?.makeFirstResponder(self) }
        textEntry.removeFromSuperview()
        self.textEntry = nil
        textMark = nil
        return true
    }
}
