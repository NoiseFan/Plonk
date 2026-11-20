import AppKit

final class QuickShotControls {
    let dimensions = QuickShotDimensions()
    let toolbar: QuickShotToolbar
    let feedback = QuickShotSurface(radius: 9, insets: NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10))
    private let message = NSTextField(labelWithString: "")

    init(canvas: QuickShotCanvas) {
        toolbar = QuickShotToolbar(canvas: canvas)
        feedback.isHidden = true
        message.lineBreakMode = .byTruncatingTail
        message.widthAnchor.constraint(lessThanOrEqualToConstant: 320).isActive = true
        feedback.stack.addArrangedSubview(message)
        for view in [dimensions, toolbar, feedback] { canvas.addSubview(view) }
        dimensions.onResize = { [weak canvas] value, horizontal in canvas?.resize(value, horizontal: horizontal) }
        dimensions.onLock = { [weak canvas] locked in canvas?.lockAspectRatio(locked) }
        dimensions.onEndEditing = { [weak canvas] in canvas?.window?.makeFirstResponder(canvas) }
    }

    func contains(_ point: CGPoint) -> Bool {
        [dimensions, toolbar, feedback].contains { !$0.isHidden && $0.frame.contains(point) }
    }

    func place(around rect: CGRect, in area: CGRect, viewportWidth: CGFloat) {
        let compact = viewportWidth <= 620
        let availableWidth = area.width - 10
        let width = compact && !dimensions.isHidden
            ? min(availableWidth, max(220, rect.width)) : availableWidth
        let size = toolbar.sizeToFit(availableWidth: width, compact: compact)
        let frames = QuickShotLayout.place(dimensions: dimensions.isHidden ? nil : dimensions.frame.size,
                                          toolbar: size, selection: rect, area: area)
        dimensions.setFrameOrigin(frames.dimensions.origin)
        toolbar.frame = frames.toolbar
        if !feedback.isHidden {
            let size = feedback.stack.fittingSize
            let gap: CGFloat = 7
            var frame = CGRect(origin: CGPoint(x: area.maxX - size.width - gap, y: area.minY + gap), size: size)
            if frame.intersects(frames.dimensions) { frame.origin.y = frames.dimensions.maxY + gap }
            if frame.intersects(frames.toolbar) { frame.origin.y = frames.toolbar.maxY + gap }
            feedback.frame = frame
        }
    }

    func showFeedback(_ text: LocalizedStringResource?) {
        message.stringValue = text.map { String(localized: $0) } ?? ""
        feedback.isHidden = text == nil
    }
}
