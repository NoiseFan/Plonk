import AppKit

final class QuickShotButton: NSButton {
    private static let foreground = NSColor(srgbRed: 238 / 255, green: 241 / 255, blue: 245 / 255, alpha: 1)
    private static let cancel = NSColor(srgbRed: 1, green: 115 / 255, blue: 123 / 255, alpha: 1)
    var icon: QuickShotIcon { didSet { needsDisplay = true } }
    private let iconSize: CGFloat
    private let radius: CGFloat
    private let invoke: (QuickShotButton) -> Void

    init(_ icon: QuickShotIcon, title: LocalizedStringResource, toggle: Bool = false,
         iconSize: CGFloat = 24, radius: CGFloat = 8, invoke: @escaping (QuickShotButton) -> Void) {
        self.icon = icon
        self.iconSize = iconSize
        self.radius = radius
        self.invoke = invoke
        super.init(frame: .zero)
        self.title = ""
        setButtonType(toggle ? .toggle : .momentaryPushIn)
        isBordered = false
        focusRingType = .exterior
        let label = String(localized: title)
        toolTip = label
        setAccessibilityLabel(label)
        target = self
        action = #selector(activate)
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let color: NSColor
        switch icon {
        case .cancel: color = Self.cancel
        case .lock, .unlock: color = .white
        default: color = Self.foreground
        }
        icon.draw(center: CGPoint(x: bounds.midX, y: bounds.midY), size: iconSize,
                  color: color.withAlphaComponent(isEnabled ? 1 : 0.3))
    }

    override var focusRingMaskBounds: NSRect { bounds }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: isEnabled ? .pointingHand : .arrow)
    }

    @objc private func activate() { invoke(self) }
}
