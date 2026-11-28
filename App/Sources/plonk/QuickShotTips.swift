import AppKit

final class QuickShotTips: NSView {
    private static let padding: CGFloat = 10
    private static let lineHeight: CGFloat = 19
    private static let textStyle: [NSAttributedString.Key: Any] = [
        .font: NSFont(name: "Inter-Regular", size: 16) ?? NSFont.systemFont(ofSize: 16),
        .foregroundColor: NSColor(srgbRed: 245 / 255, green: 245 / 255, blue: 245 / 255, alpha: 1),
    ]
    private var lines: [NSAttributedString] = []

    init(_ tips: [LocalizedStringResource]) {
        super.init(frame: .zero)
        isHidden = true
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setTips(tips)
    }

    required init?(coder: NSCoder) { nil }
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Replaces the lines and keeps the bottom edge in place, since the canvas
    /// this sits on is flipped and anchors it there.
    func setTips(_ tips: [LocalizedStringResource]) {
        let bottom = frame.maxY
        let titles = tips.map { String(localized: $0) }
        lines = titles.map { NSAttributedString(string: $0, attributes: Self.textStyle) }
        let width = lines.map { ceil($0.size().width) }.max() ?? 0
        let size = CGSize(width: width + 2 * Self.padding,
                          height: CGFloat(lines.count) * Self.lineHeight + 2 * Self.padding)
        frame = CGRect(origin: CGPoint(x: frame.minX, y: bottom - size.height), size: size)
        setAccessibilityLabel(titles.joined(separator: "\n"))
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 3, yRadius: 3).fill()
        for (index, line) in lines.enumerated() {
            let top = Self.padding + CGFloat(index) * Self.lineHeight
            line.draw(at: CGPoint(x: Self.padding, y: top + (Self.lineHeight - line.size().height) / 2))
        }
    }
}
