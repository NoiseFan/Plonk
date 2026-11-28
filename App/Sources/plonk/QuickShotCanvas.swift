import AppKit
import Combine

final class QuickShotCanvas: NSView {
    private let bitmap: ShotBitmap
    private let annotation: ShotAnnotationState
    private let safeArea: CGRect
    private let fixed: Bool
    private let backdrop: QuickShotBackdrop
    private let markup: QuickShotMarkupView
    private var history = AnnotationHistory()
    private var selection: CGRect?
    private var aspectRatio: CGFloat?
    private var gesture: QuickShotGesture?
    private var pointerArea: NSTrackingArea?
    private lazy var controls = QuickShotControls(fixed: fixed, safeArea: safeArea) { [weak self] in self?.perform($0) }
    private var accentObservation: AnyCancellable?
    var onCancel: (() -> Void)?
    var onSelect: (() -> Void)?
    var marksAnywhere: (() -> Bool)?
    var onSelectDisplay: (() -> Void)?
    var onDragStateChange: (() -> Void)?
    var startsOnWindow: ((CGPoint) -> Bool)?
    var onOutput: ((QuickShotOutput, ShotCrop) -> Void)?

    init(bitmap: ShotBitmap, size: CGSize, safeArea: CGRect, fixed: Bool, model: AppModel = AppModel(),
         annotation: ShotAnnotationState? = nil) {
        self.bitmap = bitmap
        self.annotation = annotation ?? ShotAnnotationState(defaults: model.config.shotAnnotationStyles)
        self.safeArea = safeArea
        self.fixed = fixed
        let frame = CGRect(origin: .zero, size: size)
        backdrop = QuickShotBackdrop(image: bitmap.image, frame: frame, fixed: fixed)
        markup = QuickShotMarkupView(frame: frame)
        super.init(frame: frame)
        if fixed {
            wantsLayer = true
            layer?.backgroundColor = NSColor(calibratedWhite: 0.11, alpha: 1).cgColor
            selection = CGRect(origin: .zero, size: bitmap.size)
        }
        addSubview(backdrop)
        addSubview(markup)
        controls.views.forEach { addSubview($0) }
        accentObservation = model.$config.map(\.appearance).removeDuplicates().sink { [weak self] appearance in
            self?.controls.toolbar.accent = appearance.accent
        }
        let dimensions = controls.dimensions
        dimensions.canvas = self
        dimensions.onResize = { [weak self] value, horizontal in
            guard let self, let selection else { return }
            let resized = geometry.resize(selection, dimension: CGFloat(value), horizontal: horizontal,
                                          ratio: aspectRatio)
            self.selection = resized
            refresh()
            if Int(horizontal ? resized.width : resized.height) != value {
                HUD.shared.show(.shotSelectionFitted(Int(resized.width), Int(resized.height)))
            }
        }
        dimensions.onToggleLock = { [weak self] in
            guard let self, let selection else { return }
            aspectRatio = aspectRatio == nil ? selection.width / selection.height : nil
            refresh()
        }
        dimensions.onSizeChange = { [weak self] in
            guard let self, let selection, !controls.dimensions.isHidden else { return }
            controls.place(over: geometry.viewRect(selection), annotation: self.annotation)
        }
        refresh()
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var hasMarks: Bool { history.canUndo || history.canRedo }
    /// A region being drawn or resized, which only the canvas it started on samples.
    var isDraggingRegionBoundary: Bool { gesture?.isDraggingRegionBoundary == true }

    private var geometry: ShotSelection { ShotSelection(pixels: bitmap.size, view: bounds.size) }
    private var entireDisplay: CGRect { CGRect(origin: .zero, size: bitmap.size) }

    private var drawingRegion: ShotRegionGesture? { gesture?.drawingRegion }

    var hasSelection: Bool { selection != nil }
    var isTrackingPointer: Bool { gesture != nil }
    var isWaitingForSelection: Bool { !fixed && !hasSelection && drawingRegion == nil }

    var hint: QuickShotTips? { controls.hint }

    /// The region on screen in view points: the one being drawn, else the selection.
    var regionFrame: CGRect? {
        let region = if let draft = drawingRegion { geometry.selection(from: draft.start, to: draft.end) } else { selection }
        return region.map(geometry.viewRect)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let pointerArea { removeTrackingArea(pointerArea) }
        let area = NSTrackingArea(rect: .zero, options: [.activeAlways, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        pointerArea = area
    }

    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard !controls.contains(point) else { return }
        if fixed { return (annotation.tool != nil && backdrop.frame.contains(point) ? NSCursor.crosshair : .arrow).set() }
        switch press(at: point) {
        case .adjust(let handle) where handle != .zero: QuickShotResizeCursor.forHandle(handle).set()
        case .adjust: NSCursor.openHand.set()
        default: NSCursor.crosshair.set()
        }
    }

    private func press(at point: CGPoint) -> QuickShotPress {
        let handle = selection.map { geometry.handle(at: point, of: $0) } ?? .zero
        let inside = selection.map { geometry.viewRect($0).contains(point) } ?? false
        return QuickShotPress(handle: handle, insideSelection: inside, coversDisplay: selection == entireDisplay,
                              drawing: annotation.tool != nil, marksExist: marksAnywhere?() ?? hasMarks)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard !controls.contains(point) else { return }
        if let window {
            if !window.isKeyWindow { window.makeKey() }
            window.makeFirstResponder(self)
        }
        if fixed {
            if backdrop.frame.contains(point) { beginMark(at: point) }
            return
        }
        switch press(at: point) {
        case .mark:
            beginMark(at: point)
        case .adjust(let handle):
            guard let selection else { return }
            gesture = .adjust(from: geometry.pixelPoint(point), original: selection, handle: handle)
            if handle == .zero { NSCursor.closedHand.set() }
        case .select:
            gesture = .create(ShotRegionGesture(start: point, startsOnWindow: startsOnWindow?(point) == true))
        case .ignore:
            return
        }
    }

    private func beginMark(at point: CGPoint) {
        let start = ImageFit.unitPoint(point, in: backdrop.frame)
        guard annotation.beginMark(in: &history, at: start, viewWidth: backdrop.frame.width) else { return }
        gesture = .mark
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch gesture {
        case .create(var region):
            let wasDragging = region.isDragging
            region.update(to: point)
            gesture = .create(region)
            if region.isDragging != wasDragging { onDragStateChange?() }
            guard region.isDragging else { return }
        case .adjust(let start, let original, let handle):
            let current = geometry.pixelPoint(point)
            let delta = CGPoint(x: current.x - start.x, y: current.y - start.y)
            selection = handle == .zero ? geometry.move(original, by: delta)
                : geometry.resize(original, handle: handle, by: delta, ratio: aspectRatio)
        case .mark:
            history.drag(to: ImageFit.unitPoint(point, in: backdrop.frame), squareIn: squareSize(for: event))
        case nil:
            return
        }
        refresh()
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        switch gesture {
        case .create(var region):
            region.update(to: point)
            gesture = nil
            if region.isDragging {
                if let rect = geometry.selection(from: region.start, to: region.end) {
                    confirmSelection(rect)
                } else {
                    onDragStateChange?()
                }
            } else if !region.startsOnWindow {
                // Only a click on exposed desktop selects the display; one on a window does nothing.
                onSelectDisplay?()
            }
        case .mark:
            history.end(at: ImageFit.unitPoint(point, in: backdrop.frame), squareIn: squareSize(for: event))
        case .adjust:
            mouseDragged(with: event)
        case nil:
            return
        }
        gesture = nil
        refresh()
        mouseMoved(with: event)
    }

    override func flagsChanged(with event: NSEvent) {
        if case .mark = gesture, history.updateSquareConstraint(in: squareSize(for: event)) { refresh() }
        super.flagsChanged(with: event)
    }

    private func squareSize(for event: NSEvent) -> CGSize? {
        event.modifierFlags.contains(.shift) ? bitmap.size : nil
    }

    func handle(_ command: ShotKeyCommand) {
        if command == .selectDisplay { onSelectDisplay?(); return }
        if let action = command.toolbarAction { perform(action) }
    }

    /// Replaces selection and marks with `rect` in pixels, or the whole display.
    func select(_ rect: CGRect? = nil) {
        let rect = rect ?? entireDisplay
        guard !fixed, selection != rect else { return }
        confirmSelection(rect)
        refresh()
    }

    private func confirmSelection(_ rect: CGRect) {
        resetSelectionEditing()
        selection = rect
        onSelect?()
    }

    func clearSelection() {
        guard !fixed, selection != nil else { return }
        gesture = nil
        selection = nil
        resetSelectionEditing()
        refresh()
    }

    private func resetSelectionEditing() {
        aspectRatio = nil
        history = AnnotationHistory()
        annotation.tool = nil
    }

    func selectDimension(at point: CGPoint) -> Bool {
        controls.dimensions.selectField(at: point)
    }

    func handlesStyleClick(at windowPoint: CGPoint) -> Bool {
        controls.handlesStyleClick(at: convert(windowPoint, from: nil))
    }

    private func refresh() {
        controls.toolbar.update(tool: annotation.tool, history: history)
        if fixed {
            let frame = controls.placeFixed(imageSize: bitmap.displaySize, annotation: annotation)
            backdrop.frame = frame
            markup.frame = frame
            markup.show(history, clippedTo: markup.bounds)
            return
        }

        let draft = drawingRegion
        let frame = regionFrame
        backdrop.selection = frame
        markup.show(history, clippedTo: draft == nil ? frame : nil)
        controls.showRegion(selection != nil && draft == nil)
        guard draft == nil, let selection, let frame else { return }
        controls.dimensions.update(size: selection.size, locked: aspectRatio != nil)
        controls.place(over: frame, annotation: annotation)
    }

    private func perform(_ action: QuickShotToolbar.Action) {
        window?.makeFirstResponder(self)
        switch action {
        case .tool(let choice): annotation.tool = annotation.tool == choice ? nil : choice
        case .undo: history.undo()
        case .redo: history.redo()
        case .cancel:
            onCancel?()
            return
        case .output(let action):
            guard let selection, gesture == nil else { return }
            guard let crop = ShotCrop(bitmap: bitmap, rect: selection, history: history) else {
                HUD.shared.show(.shotEditorRenderFailed)
                return
            }
            onOutput?(action, crop)
            return
        }
        refresh()
    }
}
