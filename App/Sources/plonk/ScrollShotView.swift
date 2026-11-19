import AppKit

final class ScrollShotView: NSView {
    private let selection: CGRect
    private let accent: NSColor
    private let preview = NSImageView()
    private let message = NSTextField(wrappingLabelWithString: "")
    private let panel = NSVisualEffectView()
    private let targets: [(pid_t, CGRect)]
    private var canScroll = false

    init(frame: CGRect, selection: CGRect, safeArea: CGRect, accent: NSColor) {
        self.selection = selection
        self.accent = accent
        targets = Self.scrollTargets()
        super.init(frame: frame)
        let width: CGFloat = 212
        let height = min(410, safeArea.height - 16)
        let right = selection.maxX + 8
        let left = selection.minX - width - 8
        let x = right + width <= safeArea.maxX ? right : max(safeArea.minX + 8, left)
        panel.frame = CGRect(x: x, y: max(safeArea.minY + 8, min(selection.minY, safeArea.maxY - height - 8)),
                             width: width, height: height)
        panel.material = .hudWindow
        panel.blendingMode = .withinWindow
        panel.state = .active
        panel.wantsLayer = true
        panel.layer?.cornerRadius = 12
        panel.layer?.masksToBounds = true
        preview.frame = CGRect(x: 10, y: 40, width: width - 20, height: height - 50)
        preview.imageScaling = .scaleProportionallyUpOrDown
        message.frame = CGRect(x: 10, y: 5, width: width - 20, height: 32)
        message.font = .systemFont(ofSize: 11)
        panel.addSubview(preview)
        panel.addSubview(message)
        addSubview(panel)
        show(.shotScrollStarting)
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    private static func scrollTargets() -> [(pid_t, CGRect)] {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] ?? []).compactMap { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  info[kCGWindowLayer as String] as? Int == 0,
                  let bounds = info[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
            return (pid, rect)
        }
    }

    func update(_ image: CGImage?, status: ScrollShotCapture.Status) {
        if let image { preview.image = NSImage(bitmap: image) }
        switch status {
        case .ready:
            canScroll = true
            show(.shotScrollReady)
        case .paused:
            show(.shotScrollPaused)
        case .full:
            canScroll = false
            show(.shotScrollFull)
        case .failed:
            canScroll = false
            show(.shotScrollFailed)
        }
    }

    func finishing() {
        canScroll = false
        show(.shotScrollFinishing)
    }

    private func show(_ text: LocalizedStringResource) {
        message.stringValue = String(localized: text)
    }

    override func scrollWheel(with event: NSEvent) {
        guard canScroll, selection.contains(convert(event.locationInWindow, from: nil)), let cgEvent = event.cgEvent,
              let target = targets.first(where: { $0.1.contains(cgEvent.location) }) else { return }
        cgEvent.postToPid(target.0)
    }

    override func draw(_ dirtyRect: CGRect) {
        // A nonzero alpha keeps the overlay hit-testable while exposing the live desktop.
        NSColor.black.withAlphaComponent(0.02).setFill()
        bounds.fill()
        accent.setStroke()
        let outline = NSBezierPath(rect: selection)
        outline.lineWidth = 2
        outline.stroke()
    }
}
