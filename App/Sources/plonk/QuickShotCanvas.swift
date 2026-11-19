import AppKit

final class QuickShotCanvas: ShotMarkupCanvas {
    var onSelect: (() -> Void)?
    var onStartScroll: (() -> Void)?
    var onCancel: (() -> Void)?
    var onAction: ((NSImage, AnnotationHistory, QuickShotAction) -> Void)?

    private let bitmap: ShotBitmap
    override var sourceBitmap: ShotBitmap? { bitmap }
    private let backdrop: NSImage
    private let geometry: ShotSelection
    private let safeArea: CGRect
    let controls: QuickShotControls
    private let fixed: Bool
    var scrollRegion: CGRect? { fixed ? nil : rect.map(geometry.viewRect) }
    var scrollPixels: CGSize? { rect?.size }
    private let accent: NSColor
    private lazy var tools = ShotMarkupTools(canvas: self, kinds: [
        .rectangle, .ellipse, .line, .arrow, .pen, .spotlight, .text, .step, .mosaic, .redact
    ],
                                            includeSelection: true, accent: accent)
    private var rect: CGRect? {
        didSet {
            if rect != oldValue { dismissRecognition() }
            refresh()
        }
    }
    var recognitionToken = 0
    var recognizing = false
    var recognizedText: ShotTextSelectionView?
    private var pointerArea: NSTrackingArea?
    private var ratio: CGFloat?
    private var anchor = CGPoint.zero
    private var original: CGRect?
    private var handle = CGPoint.zero
    private var dragging = false

    init(bitmap: ShotBitmap, frame: CGRect, safeArea: CGRect, accent: NSColor, fixed: Bool = false) {
        self.fixed = fixed
        controls = QuickShotControls(fixed: fixed)
        self.bitmap = bitmap
        self.safeArea = safeArea
        self.accent = accent
        backdrop = NSImage(cgImage: bitmap.image, size: frame.size)
        geometry = ShotSelection(pixels: bitmap.size, view: frame.size)
        super.init(frame: frame)
        controls.toolbar.stack.insertArrangedSubview(tools.stack, at: 0)
        controls.toolbar.stack.setCustomSpacing(10, after: tools.stack)
        addSubview(controls.dimensions)
        addSubview(controls.toolbar)
        addSubview(controls.feedback)
        controls.onResize = { [weak self] value, horizontal in self?.resize(value, horizontal: horizontal) }
        controls.onLock = { [weak self] locked in
            self?.ratio = locked ? self?.rect.map { $0.width / $0.height } : nil
        }
        controls.onCancel = { [weak self] in self?.onCancel?() }
        controls.onAction = { [weak self] action in self?.perform(action) }
        controls.onEndEditing = { [weak self] in self?.window?.makeFirstResponder(self) }
        if fixed { rect = geometry.bounds }
        refresh()
    }

    required init?(coder: NSCoder) { nil }
    override var imageRect: CGRect {
        guard fixed else { return bounds }
        let area = safeArea.insetBy(dx: 12, dy: 46)
        let scale = min(area.width / bitmap.size.width, area.height / bitmap.size.height, 1)
        let size = CGSize(width: bitmap.size.width * scale, height: bitmap.size.height * scale)
        return CGRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2,
                      width: size.width, height: size.height)
    }
    override var markupClip: CGRect { fixed ? imageRect : rect.map(geometry.viewRect) ?? .zero }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func clearSelection() {
        ratio = nil
        dragging = false
        controls.resetLock()
        rect = nil
        tools.select(nil)
    }

    override func resetCursorRects() {
        guard !fixed else { return }
        addCursorRect(bounds, cursor: .crosshair)
        guard let rect else { return }
        addCursorRect(geometry.viewRect(rect), cursor: tool == .text ? .iBeam : tool == nil ? .openHand : .crosshair)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerArea { removeTrackingArea(pointerArea) }
        let area = NSTrackingArea(rect: .zero, options: [.inVisibleRect, .activeInKeyWindow, .mouseMoved],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        pointerArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        guard !fixed else { return }
        let point = convert(event.locationInWindow, from: nil)
        let chrome = [controls.dimensions, controls.toolbar, controls.feedback]
        guard !chrome.contains(where: { !$0.isHidden && $0.frame.contains(point) }),
              let rect else { return }
        let selection = geometry.viewRect(rect)
        if selection.insetBy(dx: -5, dy: -5).contains(point) {
            let handle = edge(at: point, of: selection)
            if handle != .zero {
                resizeCursor(for: handle).set()
                return
            }
        }
        let cursor: NSCursor = selection.contains(point) ? (tool == .text ? .iBeam : tool == nil ? .openHand : .crosshair)
            : .crosshair
        cursor.set()
    }

    private func resizeCursor(for handle: CGPoint) -> NSCursor {
        if #available(macOS 15, *) {
            if handle.x == 0 { return .rowResize(directions: .all) }
            if handle.y == 0 { return .columnResize(directions: .all) }
            let position: NSCursor.FrameResizePosition = handle.y < 0
                ? (handle.x < 0 ? .topLeft : .topRight)
                : (handle.x < 0 ? .bottomLeft : .bottomRight)
            return .frameResize(position: position, directions: .all)
        }
        return handle.x == 0 ? .resizeUpDown : .resizeLeftRight
    }

    override func mouseDown(with event: NSEvent) {
        guard commitText() else { return }
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        if fixed { _ = beginMark(at: point); return }
        anchor = geometry.pixelPoint(point)
        original = nil
        handle = .zero
        if let rect {
            let viewRect = geometry.viewRect(rect)
            if viewRect.insetBy(dx: -5, dy: -5).contains(point) {
                original = rect
                handle = edge(at: point, of: viewRect)
            }
        }
        if handle == .zero && beginMark(at: point) { return }
        if original == nil { clearSelection() }
        if original != nil && handle == .zero { NSCursor.closedHand.set() }
        dragging = true
        onSelect?()
        refresh()
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        if dragMark(to: location) { return }
        guard dragging else { return }
        let point = geometry.pixelPoint(location)
        let delta = CGPoint(x: point.x - anchor.x, y: point.y - anchor.y)
        if let original {
            rect = handle == .zero ? geometry.move(original, by: delta)
                : geometry.drag(original, handle: handle, delta: delta, ratio: ratio)
        } else {
            let selection = CGRect(spanning: anchor, point)
            rect = selection.isEmpty ? nil : selection
        }
    }

    override func mouseUp(with event: NSEvent) {
        if endMark(at: convert(event.locationInWindow, from: nil)) { return }
        guard dragging else { return }
        mouseDragged(with: event)
        dragging = false
        if let rect, original == nil {
            let viewRect = geometry.viewRect(rect)
            if viewRect.width < 3 || viewRect.height < 3 { self.rect = nil }
        }
        refresh()
        window?.invalidateCursorRects(for: self)
    }

    private func edge(at point: CGPoint, of rect: CGRect) -> CGPoint {
        func side(_ position: CGFloat, _ start: CGFloat, _ end: CGFloat) -> CGFloat {
            let distance = min(abs(position - start), abs(position - end))
            guard distance <= 5 else { return 0 }
            return position <= (start + end) / 2 ? -1 : 1
        }
        return CGPoint(x: side(point.x, rect.minX, rect.maxX), y: side(point.y, rect.minY, rect.maxY))
    }

    private func resize(_ dimension: Int, horizontal: Bool) {
        guard let rect else { return }
        self.rect = geometry.resize(rect, dimension: CGFloat(dimension), horizontal: horizontal, ratio: ratio)
        window?.invalidateCursorRects(for: self)
    }

    func perform(_ action: QuickShotAction) {
        guard controls.commitDimensions(), commitText(), let rect else { return }
        if case .recognizeText = action, recognizedText != nil {
            dismissRecognition()
            return
        }
        if case .scroll = action {
            if !fixed { onStartScroll?() }
            return
        }
        if fixed {
            onAction?(NSImage(bitmap: bitmap.image), history, action)
            return
        }
        guard let image = bitmap.crop(rect) else { return }
        let crop = CGRect(x: rect.minX / bitmap.size.width, y: rect.minY / bitmap.size.height,
                          width: rect.width / bitmap.size.width, height: rect.height / bitmap.size.height)
        onAction?(image, history.rebased(to: crop), action)
    }

    func selectTool(_ kind: Annotation.Kind) {
        guard rect != nil else { return }
        tools.select(kind)
    }

    func refresh() {
        needsDisplay = true
        updateMarkup()
        controls.dimensions.isHidden = fixed || rect == nil
        controls.toolbar.isHidden = rect == nil || dragging
        guard let rect else { return }
        controls.update(width: Int(rect.width), height: Int(rect.height))
        controls.place(around: markupClip, in: safeArea)
    }

    override func draw(_ dirtyRect: NSRect) {
        if fixed {
            NSColor.black.withAlphaComponent(0.86).setFill()
            bounds.fill()
            backdrop.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1,
                          respectFlipped: true, hints: nil)
            return
        }
        backdrop.draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        let shade = NSBezierPath(rect: bounds)
        if let rect { shade.appendRect(geometry.viewRect(rect)) }
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.42).setFill()
        shade.fill()
        guard let rect else { return }
        let selection = geometry.viewRect(rect)
        let outline = NSBezierPath(rect: selection)
        accent.setStroke()
        outline.lineWidth = 1
        outline.stroke()
        drawHandles(of: selection)
    }

    private func drawHandles(of rect: CGRect) {
        let side = min(rect.width / 3, rect.height / 3, 11)
        guard side >= 2 else { return }
        let corners = NSBezierPath()
        for (x, dx) in [(rect.minX, side), (rect.maxX, -side)] {
            for (y, dy) in [(rect.minY, side), (rect.maxY, -side)] {
                corners.move(to: CGPoint(x: x + dx, y: y))
                corners.line(to: CGPoint(x: x, y: y))
                corners.line(to: CGPoint(x: x, y: y + dy))
            }
        }
        corners.lineWidth = 4
        corners.lineCapStyle = .round
        corners.lineJoinStyle = .round
        accent.setStroke()
        corners.stroke()
    }
}
