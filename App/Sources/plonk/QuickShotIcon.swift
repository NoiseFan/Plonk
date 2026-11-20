import AppKit

enum QuickShotIcon {
    case unlock, lock, move, rectangle, ellipse, arrow, pen, text, undo, redo
    case cancel, preview, ocr, editor, folder, save, copy

    func draw(center: CGPoint, size: CGFloat, color: NSColor) {
        let optics = optics
        let unit = size / 24
        let scale = unit * optics.scale
        var transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
                                          tx: center.x + unit * optics.x - 12 * scale,
                                          ty: center.y + unit * optics.y - 12 * scale)
        guard let context = NSGraphicsContext.current?.cgContext,
              let path = path.copy(using: &transform) else { return }
        context.saveGState()
        context.addPath(path)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(optics.weight * unit)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
        context.restoreGState()
    }

    private var optics: (scale: CGFloat, x: CGFloat, y: CGFloat, weight: CGFloat) {
        switch self {
        case .arrow: return (1.18, -0.9, 1.2, 1.8)
        case .text: return (1.05, 0, 0, 1.8)
        case .undo: return (1, 0.35, -0.25, 1.8)
        case .redo: return (1, -0.35, -0.25, 1.8)
        case .cancel: return (1.12, 0, 0, 1.8)
        case .preview: return (0.94, 0, 0, 1.6)
        case .editor: return (0.94, 0, 0.4, 1.6)
        case .save: return (1, 0, -1, 1.8)
        case .folder: return (1, 0.2, -0.7, 1.8)
        default: return (1, 0, 0, 1.8)
        }
    }

    // Coordinates and optical adjustments use the prototype's 24-point canvas.
    private var path: CGPath {
        let path = CGMutablePath()
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
        func line(_ points: CGPoint...) { path.addLines(between: points) }
        func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
            path.addRect(CGRect(x: x, y: y, width: width, height: height))
        }
        func arc(_ x: CGFloat, _ y: CGFloat, radius: CGFloat, from: CGFloat, to: CGFloat, clockwise: Bool) {
            path.addArc(center: point(x, y), radius: radius, startAngle: from, endAngle: to, clockwise: clockwise)
        }
        switch self {
        case .unlock, .lock:
            line(point(8, 11), point(8, 8))
            arc(12, 8, radius: 4, from: .pi, to: self == .lock ? 2 * .pi : 11 * .pi / 6, clockwise: false)
            if self == .lock { path.addLine(to: point(16, 11)) }
            rect(7, 11, 10, 9)
            line(point(12, 15), point(12, 17))
        case .move:
            line(point(12, 3), point(12, 21))
            line(point(3, 12), point(21, 12))
            line(point(9, 6), point(12, 3), point(15, 6))
            line(point(9, 18), point(12, 21), point(15, 18))
            line(point(6, 9), point(3, 12), point(6, 15))
            line(point(18, 9), point(21, 12), point(18, 15))
        case .rectangle:
            path.addRoundedRect(in: CGRect(x: 3, y: 3, width: 18, height: 18), cornerWidth: 3, cornerHeight: 3)
        case .ellipse:
            path.addEllipse(in: CGRect(x: 3, y: 3, width: 18, height: 18))
        case .arrow:
            line(point(5, 18), point(19, 5))
            line(point(10, 5), point(19, 5), point(19, 14))
        case .pen:
            line(point(4, 20), point(9, 19), point(20, 8), point(16, 4), point(5, 15))
            path.closeSubpath()
            line(point(14, 6), point(18, 10))
        case .text:
            line(point(4, 20), point(11, 4), point(13, 4), point(20, 20))
            line(point(7, 14), point(17, 14))
        case .undo:
            line(point(8, 5), point(3, 10), point(8, 15))
            line(point(3, 10), point(15, 10))
            arc(15, 15, radius: 5, from: -.pi / 2, to: .pi / 2, clockwise: false)
        case .redo:
            line(point(16, 5), point(21, 10), point(16, 15))
            line(point(21, 10), point(9, 10))
            arc(9, 15, radius: 5, from: -.pi / 2, to: -3 * .pi / 2, clockwise: true)
        case .cancel:
            line(point(5, 5), point(19, 19))
            line(point(19, 5), point(5, 19))
        case .preview:
            rect(3, 5, 18, 14)
            line(point(3, 15), point(8, 10), point(12, 14), point(15, 11), point(21, 17))
            line(point(15, 8), point(17, 8))
        case .ocr:
            line(point(3, 8), point(3, 4), point(8, 4))
            line(point(16, 4), point(21, 4), point(21, 8))
            line(point(3, 16), point(3, 20), point(8, 20))
            line(point(16, 20), point(21, 20), point(21, 16))
            line(point(8, 9), point(16, 9))
            line(point(8, 12), point(16, 12))
            line(point(8, 15), point(14, 15))
        case .editor:
            rect(3, 5, 18, 14)
            line(point(3, 9), point(21, 9))
            line(point(6, 7), point(6.2, 7))
            line(point(9, 7), point(9.2, 7))
        case .folder:
            line(point(3, 6), point(10, 6), point(12, 8), point(21, 8), point(21, 19), point(3, 19))
            path.closeSubpath()
        case .save:
            line(point(12, 3), point(12, 15))
            line(point(8, 11), point(12, 15), point(16, 11))
            line(point(4, 15), point(4, 20), point(20, 20), point(20, 15))
        case .copy:
            path.addRoundedRect(in: CGRect(x: 8, y: 8, width: 12, height: 12), cornerWidth: 2, cornerHeight: 2)
            line(point(14, 4), point(6, 4))
            arc(6, 6, radius: 2, from: -.pi / 2, to: -.pi, clockwise: true)
            path.addLine(to: point(4, 14))
        }
        return path
    }
}
