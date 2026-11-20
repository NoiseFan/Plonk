import AppKit
import Carbon.HIToolbox

final class QuickShotWindow: NSWindow {
    private(set) var canvas: QuickShotCanvas
    var onScrollKey: ((Bool) -> Void)?
    var onCancel: (() -> Void)?

    init(screen: NSScreen, bitmap: ShotBitmap, fixed: Bool = false) {
        let frame = screen.frame
        let visible = screen.visibleFrame
        canvas = QuickShotCanvas(bitmap: bitmap, frame: CGRect(origin: .zero, size: frame.size),
                                safeArea: CGRect(x: visible.minX - frame.minX, y: frame.maxY - visible.maxY,
                                                 width: visible.width, height: visible.height),
                                fixed: fixed)
        super.init(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(frame, display: false)
        level = .screenSaver
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = canvas
        initialFirstResponder = canvas
        autorecalculatesKeyViewLoop = true
        canvas.onCancel = { [weak self] in self?.onCancel?() }
    }

    func showScroll(_ view: ScrollShotView) {
        isOpaque = false
        backgroundColor = .clear
        contentView = view
        makeFirstResponder(view)
    }

    func showCanvas(_ replacement: QuickShotCanvas? = nil) {
        if let replacement { canvas = replacement }
        isOpaque = true
        backgroundColor = .windowBackgroundColor
        contentView = canvas
        initialFirstResponder = canvas
        makeFirstResponder(canvas)
    }

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) { onCancel?() }

    override func sendEvent(_ event: NSEvent) {
        // AppKit forwards the first click to the field editor, which places a caret.
        if event.type == .leftMouseDown, contentView === canvas,
           canvas.controls.dimensions.selectField(at: event.locationInWindow) { return }
        super.sendEvent(event)
    }

    func handleShortcut(_ event: NSEvent) -> Bool {
        if let onScrollKey {
            let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
            if flags.isEmpty && !event.isARepeat {
                switch Int(event.keyCode) {
                case kVK_Escape: onScrollKey(false)
                case kVK_Return, kVK_ANSI_KeypadEnter: onScrollKey(true)
                default: break
                }
            }
            return true
        }
        if canvas.recognizedText != nil,
           event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
           !event.isARepeat, event.keyCode == kVK_ANSI_O {
            canvas.dismissRecognition()
            return true
        }
        guard let command = ShotKeyCommand(event: event, window: self, canvas: canvas) else { return false }
        switch command {
        case .cancel:
            if !canvas.cancelText() && !canvas.dismissRecognition() { onCancel?() }
        case .select(let kind): canvas.selectTool(kind)
        case .action(let action): canvas.perform(action)
        case .deleteStep: canvas.deleteStep()
        case .undo: canvas.undoMark()
        case .redo: canvas.redoMark()
        case .tab(let backward):
            if backward { selectPreviousKeyView(canvas) } else { selectNextKeyView(canvas) }
        }
        return true
    }
}
