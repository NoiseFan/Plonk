import CoreGraphics

enum QuickShotLayout {
    static let toolbarInset: CGFloat = 8
    static let toolbarVerticalInset: CGFloat = 5
    static let dividerWidth: CGFloat = 9

    static func toolbar(dividers: [Bool], availableWidth: CGFloat, compact: Bool) -> (CGSize, [CGRect]) {
        let button = CGSize(width: compact ? 30 : 34, height: compact ? 30 : 32)
        let gap: CGFloat = compact ? 2 : 3
        let limit = max(availableWidth - 2 * toolbarInset, button.width)
        var x = toolbarInset
        var y = toolbarVerticalInset
        var right = x
        let frames = dividers.map { divider in
            let width = divider ? dividerWidth : button.width
            if x > toolbarInset && x + width > toolbarInset + limit {
                x = toolbarInset
                y += button.height + gap
            }
            let frame = CGRect(x: x, y: y, width: width, height: button.height)
            right = max(right, frame.maxX)
            x = frame.maxX + gap
            return frame
        }
        let width = y == toolbarVerticalInset ? right + toolbarInset : limit + 2 * toolbarInset
        return (CGSize(width: width, height: y + button.height + toolbarVerticalInset), frames)
    }

    static func place(dimensions: CGSize?, toolbar: CGSize, selection: CGRect, area: CGRect)
        -> (dimensions: CGRect, toolbar: CGRect) {
        let area = area.insetBy(dx: 5, dy: 5)
        func origin(for size: CGSize, y: CGFloat) -> CGPoint {
            CGPoint(x: min(max(selection.minX, area.minX), max(area.minX, area.maxX - size.width)),
                    y: min(max(y, area.minY), max(area.minY, area.maxY - size.height)))
        }
        let top = dimensions.map {
            CGRect(origin: origin(for: $0, y: selection.minY - 10 - $0.height), size: $0)
        } ?? .zero
        let below = selection.maxY + 16
        let above = selection.minY - (dimensions == nil ? 16 : 10 + top.height + 8) - toolbar.height
        let y = below + toolbar.height <= area.maxY || above < area.minY ? below : above
        var bottom = CGRect(origin: origin(for: toolbar, y: y), size: toolbar)
        if bottom.intersects(top) { bottom.origin.y = top.maxY + 8 }
        return (top, bottom)
    }
}
