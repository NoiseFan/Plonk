import AppKit

final class QuickShotWindow: NSPanel {
    let canvas: QuickShotCanvas
    /// Region captures only: a window capture has no boundary to line up.
    let magnifier: QuickShotMagnifier?
    /// What a region copied, saved or opened from here is keyed to: the display and its geometry now.
    let regionDisplay: ShotRegionRecord.Display?
    /// The last region used, in pixels, when it was taken on this display as it is now.
    let restorableRegion: CGRect?
    var onRegionPointerChange: ((CGPoint) -> Void)?
    private var interactingWithStyle = false

    /// `regionDisplay` is nil for a window capture, which never offers or keeps a region.
    init(frame: CGRect, visibleFrame visible: CGRect, bitmap: ShotBitmap, fixed: Bool, model: AppModel,
         annotation: ShotAnnotationState, regionDisplay: ShotRegionRecord.Display? = nil,
         lastRegion: ShotRegionRecord? = nil) {
        let safeArea = CGRect(x: visible.minX - frame.minX, y: frame.maxY - visible.maxY,
                              width: visible.width, height: visible.height)
        canvas = QuickShotCanvas(bitmap: bitmap, size: frame.size, safeArea: safeArea, fixed: fixed,
                                 model: model, annotation: annotation)
        magnifier = fixed ? nil : QuickShotMagnifier(image: bitmap.image)
        self.regionDisplay = fixed ? nil : regionDisplay
        restorableRegion = lastRegion?.rect(on: self.regionDisplay)
        if restorableRegion != nil {
            canvas.hint?.setTips([.shotSelectDisplayHint, .shotRestoreRegionHint, .shotCopyColorHint])
        }
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        setFrame(frame, display: false)
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        animationBehavior = .none
        level = .screenSaver
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        contentView = canvas
        if let magnifier { canvas.addSubview(magnifier) }
        initialFirstResponder = canvas
    }

    override var canBecomeKey: Bool { true }

    func show() {
        canvas.layoutSubtreeIfNeeded()
        display()
        orderFrontRegardless()
    }

    func canvasPoint(at screenPoint: CGPoint) -> CGPoint {
        canvas.convert(convertPoint(fromScreen: screenPoint), from: nil)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, attachedSheet == nil {
            interactingWithStyle = canvas.handlesStyleClick(at: event.locationInWindow)
            if !interactingWithStyle, canvas.selectDimension(at: event.locationInWindow) { return }
        }
        super.sendEvent(event)
        if event.type == .leftMouseUp, interactingWithStyle {
            interactingWithStyle = false
            makeFirstResponder(canvas)
        }
        switch event.type {
        case .leftMouseDown, .leftMouseDragged, .leftMouseUp:
            onRegionPointerChange?(convertPoint(toScreen: event.locationInWindow))
        default:
            break
        }
    }

    func shortcut(for event: NSEvent) -> ShotKeyCommand? {
        guard isKeyWindow, (event.window == nil || event.window === self),
              attachedSheet == nil, firstResponder === canvas else { return nil }
        return ShotKeyCommand(keyCode: Int(event.keyCode), characters: event.charactersIgnoringModifiers,
                              flags: event.modifierFlags, repeating: event.isARepeat)
    }
}

extension ShotRegionRecord.Display {
    /// The display a region is taken on, and the geometry it has now.
    init?(screen: NSScreen, bitmap: ShotBitmap) {
        guard let uuid = ScreenIdentity.uuid(for: screen) else { return nil }
        self.init(uuid: uuid, pixels: bitmap.size, points: bitmap.displaySize, scale: screen.backingScaleFactor)
    }
}
