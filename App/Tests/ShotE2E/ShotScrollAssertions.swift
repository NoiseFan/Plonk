import AppKit

extension ShotCases {
    func scrollLengthLimit() throws {
        try startScroll()
        let full = "Length limit reached. Press Enter to finish."
        let paused = "Stitching paused. Scroll back or press Enter."
        let increment = CGFloat(119)
        var offset = increment
        while offset <= desktop.maximumScrollOffset {
            desktop.setScrollOffset(offset)
            let deadline = Date(timeIntervalSinceNow: 0.35)
            repeat {
                if desktop.element(full) != nil { return }
                if desktop.element(paused) != nil {
                    throw E2EFailure("Stitching paused at fixture offset \(offset) before reaching the length limit.")
                }
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.04))
            } while deadline.timeIntervalSinceNow > 0
            offset += increment
        }
        throw E2EFailure("Reached the fixture's end without observing the stitching limit.")
    }

    func scrollToFixtureEnd() throws {
        let region = desktop.region
        let position = CGPoint(x: region.midX, y: region.midY)
        for _ in 0..<20 {
            let before = desktop.scrollOffset
            if before >= desktop.maximumScrollOffset - 0.5 { return }
            try desktop.scrollDown(at: position)
            _ = try desktop.wait("fixture scroll position") { desktop.scrollOffset > before ? true : nil }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
        }
        guard desktop.scrollOffset >= desktop.maximumScrollOffset - 0.5 else {
            throw E2EFailure("The scroll fixture did not reach its end.")
        }
    }

    func verifyStitchedStripes(_ image: CGImage, initialHeight: Int) throws {
        let scale = CGFloat(initialHeight) / desktop.region.height
        let expectedHeight = CGFloat(initialHeight) + desktop.scrollOffset * scale
        guard abs(CGFloat(image.height) - expectedHeight) <= 3 * scale else {
            throw E2EFailure("Stitched image height \(image.height) differs from expected \(expectedHeight).")
        }

        // The selection starts 110 points below the top of the document viewport.
        // Sample each stripe's center on the left of the text column.
        let sourceStart = CGFloat(110)
        let sourceEnd = sourceStart + CGFloat(image.height) / scale
        let first = Int(ceil((sourceStart - 12.5) / 25))
        let last = Int(floor((sourceEnd - 12.5) / 25))
        guard first < last else { throw E2EFailure("The stitched image has too few reference stripes.") }
        let palette = (0..<40).map { index -> [Double] in
            let color = Desktop.stripeColor(index).usingColorSpace(.sRGB) ?? Desktop.stripeColor(index)
            return [Double(color.redComponent), Double(color.greenComponent), Double(color.blueComponent)]
        }
        for row in first...last {
            let center = CGFloat(row) * 25 + 12.5
            for offset in [-9, 0, 9] {
                let y = Int((center + CGFloat(offset) - sourceStart) * scale)
                guard y >= 0, y < image.height else { continue }
                let rgb = try pixel(image, x: image.width / 30, y: y).prefix(3).map { Double($0) / 255 }
                let index = palette.indices.min { distance(palette[$0], rgb) < distance(palette[$1], rgb) }
                guard index == 39 - row else {
                    throw E2EFailure("Incorrect stripe \(row) at output row \(y): \(String(describing: index)).")
                }
            }
        }
        let markerX = Int((340 - 100) * scale)
        let markerY = Int((887.5 - sourceStart) * scale)
        let marker = try pixel(image, x: markerX, y: markerY)
        try require(marker[0] > 230 && marker[1] < 25 && marker[2] > 230,
                    "Long screenshot did not include the end marker in its expected position.")
    }

    private func distance(_ lhs: [Double], _ rhs: [Double]) -> Double {
        zip(lhs, rhs).reduce(0) { result, channel in
            result + pow(channel.0 - channel.1, 2)
        }
    }
}
