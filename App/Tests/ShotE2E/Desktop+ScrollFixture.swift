import AppKit

extension Desktop {
    static func scrollDocument(rowCount: Int) -> NSView {
        let document = NSView(frame: CGRect(x: 0, y: 0, width: 620, height: rowCount * 25))
        document.wantsLayer = true
        for index in 0..<rowCount {
            let stripe = NSView(frame: CGRect(x: 0, y: index * 25, width: 620, height: 25))
            stripe.wantsLayer = true
            stripe.layer?.backgroundColor = Self.stripeColor(index).cgColor
            let label = NSTextField(labelWithString: "PLONK E2E ROW \(rowCount - 1 - index)")
            label.frame = CGRect(x: 120, y: 2, width: 260, height: 21)
            stripe.addSubview(label)
            if index == 4 {
                let marker = NSView(frame: CGRect(x: 325, y: 5, width: 30, height: 15))
                marker.wantsLayer = true
                marker.layer?.backgroundColor = NSColor(srgbRed: 1, green: 0, blue: 1, alpha: 1).cgColor
                stripe.addSubview(marker)
            }
            document.addSubview(stripe)
        }
        return document
    }
}
