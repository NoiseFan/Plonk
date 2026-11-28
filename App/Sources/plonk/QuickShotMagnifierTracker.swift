import AppKit

/// Which of a session's displays shows the region magnifier, where it sits and
/// how far it zooms. Only one display samples at a time.
final class QuickShotMagnifierTracker {
    private weak var current: QuickShotWindow?
    private var zoom: ShotMagnifierZoom = .standard
    private var monitor: Any?
    private let windows: () -> [QuickShotWindow]
    /// True while no display holds or is drawing a selection.
    private let isWaiting: () -> Bool

    init(windows: @escaping () -> [QuickShotWindow], isWaiting: @escaping () -> Bool) {
        self.windows = windows
        self.isWaiting = isWaiting
    }

    /// The sampled color, while the magnifier is on screen.
    var hex: String? { current?.magnifier?.hex }

    func track(_ window: QuickShotWindow) {
        window.onRegionPointerChange = { [weak self] in self?.update(at: $0) }
    }

    func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited]) { [weak self] in
            if $0.type == .mouseMoved, let window = $0.window {
                self?.update(at: window.convertPoint(toScreen: $0.locationInWindow))
            } else {
                self?.update(at: NSEvent.mouseLocation)
            }
            return $0
        }
        update(at: NSEvent.mouseLocation)
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        current?.magnifier?.hide()
        current = nil
    }

    func update(at pointer: CGPoint) {
        let windows = windows()
        let waiting = isWaiting()
        // During a drag only its starting canvas samples, even on another display.
        let target = windows.first { $0.canvas.isDraggingRegionBoundary }
            ?? (waiting ? windows.first { $0.magnifier != nil && $0.frame.contains(pointer) } : nil)
        if current !== target { current?.magnifier?.hide() }
        current = target
        guard let target, let magnifier = target.magnifier else { return }
        let canvas = target.canvas
        magnifier.showsHex = canvas.regionFrame == nil
        magnifier.update(at: target.canvasPoint(at: pointer), in: canvas.bounds,
                         avoiding: waiting ? canvas.hintFrame : canvas.regionFrame, zoom: zoom)
    }

    func zoom(increasing: Bool) {
        guard let magnifier = current?.magnifier, !magnifier.isHidden else { return }
        zoom = zoom.stepped(increasing: increasing)
        magnifier.setZoom(zoom)
    }
}
