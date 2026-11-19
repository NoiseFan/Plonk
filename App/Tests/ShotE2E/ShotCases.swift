import AppKit
import ApplicationServices
import Carbon.HIToolbox
import ImageIO

struct ShotCases {
    let desktop: Desktop

    static let ids = ["CAP-01", "CAP-02", "CAP-03", "CAP-04", "CAP-05", "SEL-01", "SEL-02", "SEL-02-corner", "SEL-03", "SEL-04", "EDIT-01-rectangle", "EDIT-01-ellipse", "EDIT-01-arrow", "EDIT-01-pen",
                      "EDIT-01-text", "EDIT-01-line", "EDIT-02", "EDIT-03", "EDIT-04", "EDIT-05", "EDIT-06", "EDIT-07", "EDIT-08", "EDIT-09", "EDIT-10", "EDIT-11", "OCR-01", "OCR-02", "OCR-02-multiline", "OCR-03", "OCR-04", "OCR-05", "OUT-01", "OUT-02", "OUT-03", "OUT-04", "OUT-05", "FOCUS-01-line", "FOCUS-01-spotlight", "FOCUS-01-step", "FOCUS-01-mosaic", "FOCUS-01-redact",
                      "FOCUS-02-width", "FOCUS-02-text", "FOCUS-02-filename", "FOCUS-03", "FOCUS-04", "FOCUS-05",
                      "SCROLL-01", "SCROLL-02", "SCROLL-03", "SCROLL-04", "SCROLL-05", "SCROLL-06", "DISPLAY-01-SEL-03", "DISPLAY-01-CAP-03", "DISPLAY-01-SCROLL-01", "DISPLAY-02", "PERM-01", "PERM-02", "SCROLL-07", "SCROLL-08", "MCP-01", "MCP-02", "UI-01", "UI-02"]

    func run(_ id: String) throws {
        desktop.showFixture(scrolling: id.hasPrefix("SCROLL-"), recognizing: id.hasPrefix("OCR-"),
                            multiline: id == "OCR-02-multiline",
                            patterned: ["SEL-01", "EDIT-06", "EDIT-07", "EDIT-10"].contains(id),
                            longScroll: id == "SCROLL-07", measuring: id == "SEL-03")
        if ["CAP-02", "CAP-03", "CAP-04", "CAP-05"].contains(id) {
            try id == "CAP-02" ? directEditorCapture() : fixedCapture(id)
            return
        }
        if id == "OUT-02" {
            try defaultOutput()
            return
        }
        if id.hasPrefix("UI-") {
            try id == "UI-01" ? blueSwatchIsFirst() : blueSelectionAccent()
            return
        }
        if id.hasPrefix("MCP-") {
            try mcpAnnotation(id == "MCP-01" ? "line" : "spotlight")
            return
        }
        if id.hasPrefix("DISPLAY-") {
            try displayCase(id)
            return
        }
        if id.hasPrefix("PERM-") {
            try capturePermission(id)
            return
        }
        let baseline = desktop.windowCount()
        defer { desktop.dismissCapture(above: baseline) }
        do {
            try captureCase(id, baseline: baseline)
        } catch {
            if !(error is E2EBlocked) { recordFailureScreen() }
            throw error
        }
    }

    private func captureCase(_ id: String, baseline: Int) throws {
        if id == "FOCUS-03" {
            try globalShortcutSuspension()
            return
        }
        let region = desktop.region
        try selectRegion()

        if id == "CAP-01" {
            _ = try desktop.wait("Quick Actions toolbar") { desktop.element("Open Editor") }
            return
        }

        _ = try desktop.wait("selection ready") { desktop.element("Selection Width") }
        if id.hasPrefix("EDIT-01-") {
            try basicMarkup(String(id.dropFirst("EDIT-01-".count)))
            return
        }
        if id.hasPrefix("FOCUS-") {
            try focusCase(id, baseline: baseline)
            return
        }
        switch id {
        case "SEL-01":
            try moveSelection()
        case "SEL-02", "SEL-02-corner":
            try resizeSelection(corner: id == "SEL-02-corner")
        case "SEL-03":
            try setDimension("Selection Width", digits: [kVK_ANSI_2, kVK_ANSI_4, kVK_ANSI_0])
            try setDimension("Selection Height", digits: [kVK_ANSI_1, kVK_ANSI_6, kVK_ANSI_0])
            let image = try copySelection()
            try require(image.width == 240 && image.height == 160,
                        "Expected 240 × 160 px, got \(image.width) × \(image.height) px.")
            try verifySelectionRuler(in: image)
        case "SEL-04":
            let width = try dimension("Selection Width")
            let height = try dimension("Selection Height")
            try desktop.press("Lock Aspect Ratio")
            let edge = CGPoint(x: region.maxX, y: region.midY)
            try desktop.drag(from: edge, to: CGPoint(x: edge.x + 40, y: edge.y))
            let newWidth = try desktop.wait("locked selection width") {
                guard let current = try? dimension("Selection Width"), current != width else { return nil as Int? }
                return current
            }
            let newHeight = try dimension("Selection Height")
            let expectedHeight = Double(newWidth) * Double(height) / Double(width)
            try require(abs(Double(newHeight) - expectedHeight) <= 2, "Locked resize changed the aspect ratio.")
        case "EDIT-02":
            try desktop.key(kVK_ANSI_6)
            try mark(from: CGPoint(x: 45, y: 45), to: CGPoint(x: 105, y: 105))
            try mark(from: CGPoint(x: 210, y: 95), to: CGPoint(x: 290, y: 155))
            let image = try copySelection()
            let first = try sample(image, at: CGPoint(x: 75, y: 75))
            let second = try sample(image, at: CGPoint(x: 250, y: 125))
            let outside = try sample(image, at: CGPoint(x: 165, y: 120))
            try require(first == second && Int(first[1]) > Int(outside[1]) + 25,
                        "Expected both spotlight regions to stay brighter than the surrounding image.")
        case "EDIT-03":
            try stepNumbers()
        case "EDIT-04", "EDIT-05":
            let original = CGPoint(x: 115, y: 110)
            let target = CGPoint(x: 210, y: 110)
            try desktop.key(kVK_ANSI_8)
            try desktop.click(global(original))
            try waitForEnabledAction("Undo")
            if id == "EDIT-04" {
                try mark(from: original, to: target)
            } else {
                try desktop.click(global(original))
                try desktop.key(kVK_Delete)
            }
            let image = try copySelection()
            let background = try sample(image, at: CGPoint(x: 25, y: 25))
            let former = try sample(image, at: original)
            if id == "EDIT-04" {
                let moved = try sample(image, at: target)
                try require(former == background && moved != background && stepDigit(image, at: target) == "1",
                            "Expected the step marker to move from its original position to the target.")
            } else {
                try require(former == background, "Expected the step marker to disappear.")
            }
        case "EDIT-08", "EDIT-09", "EDIT-11":
            try desktop.key(kVK_ANSI_0)
            try mark(from: CGPoint(x: 130, y: 75), to: CGPoint(x: 225, y: 150))
            if id == "EDIT-11" {
                try desktop.press("Open Editor")
                _ = try desktop.wait("editor controls") { desktop.element("Undo") }
            }
            try waitForEnabledAction("Undo")
            try desktop.key(kVK_ANSI_Z, flags: .maskCommand)
            if id == "EDIT-09" {
                try waitForEnabledAction("Redo")
                try desktop.key(kVK_ANSI_Z, flags: [.maskCommand, .maskShift])
            }
            let image = try copySelection()
            let center = try sample(image, at: CGPoint(x: 180, y: 115))
            let background = try sample(image, at: CGPoint(x: 25, y: 25))
            if id == "EDIT-09" {
                try require(center != background, "Expected redo to restore the annotation.")
            } else {
                try require(center == background, "Expected undo to remove the annotation.")
            }
        case "EDIT-06":
            try mosaic()
        case "EDIT-10":
            try cropPreservesAnnotation()
        case "EDIT-07":
            try desktop.key(kVK_ANSI_0)
            try desktop.drag(from: CGPoint(x: region.midX - 35, y: region.midY - 35),
                             to: CGPoint(x: region.midX + 35, y: region.midY + 35))
            let image = try copySelection()
            for point in [CGPoint(x: 151, y: 113), CGPoint(x: 153, y: 113)] {
                let covered = try sample(image, at: point)
                try require(covered == [0, 0, 0, 255], "Expected opaque black fill over adjacent source checks.")
            }
        case "OCR-01", "OCR-02", "OCR-02-multiline", "OCR-03", "OCR-04", "OCR-05":
            try recognitionCase(id)
        case "OUT-01":
            let image = try copySelection()
            let color = try pixel(image, x: image.width / 2, y: image.height / 2)
            try require(color[1] > color[0] + 50 && color[2] > color[0] + 50,
                        "Clipboard image does not contain the fixture color.")
        case "OUT-03", "OUT-04", "OUT-05":
            if id == "OUT-05" { try previewOutput() }
            else { try ShotOutputCases(desktop: desktop).saveAs(cancel: id == "OUT-04") }
        case "SCROLL-01", "SCROLL-02":
            let initialHeight = try dimension("Selection Height")
            try startScroll()
            if id == "SCROLL-01" {
                try scrollToFixtureEnd()
            } else {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.6))
            }
            try desktop.key(kVK_Return)
            let image = try copySelection()
            if id == "SCROLL-01" {
                try verifyStitchedStripes(image, initialHeight: initialHeight)
            } else {
                try require(image.height == initialHeight, "A stationary frame was duplicated.")
            }
        case "SCROLL-03", "SCROLL-04":
            try startScroll()
            desktop.setScrollOffset(400)
            _ = try desktop.wait("stitching to pause") {
                desktop.element("Stitching paused. Scroll back or press Enter.")
            }
            if id == "SCROLL-04" {
                desktop.setScrollOffset(50)
                _ = try desktop.wait("stitching to resume") {
                    desktop.element("Scroll down in the selection. Enter to finish.")
                }
            }
        case "SCROLL-05":
            try startScroll()
            try desktop.key(kVK_Escape)
            _ = try desktop.wait("original selection toolbar") { desktop.element("Selection Width") }
        case "SCROLL-06":
            try setDimension("Selection Width", digits: [kVK_ANSI_2, kVK_ANSI_4])
            try desktop.press("Scrolling Capture (S)")
            _ = try desktop.wait("small selection feedback") {
                desktop.element("Select an area at least 32 × 32 pixels.")
            }
        case "SCROLL-07":
            try scrollLengthLimit()
        case "SCROLL-08":
            try startScroll()
            try desktop.key(kVK_Return)
            try desktop.key(kVK_Return)
            _ = try desktop.wait("one result interface") {
                desktop.element("Scrolling Capture (S)") == nil ? desktop.element("Open Editor") : nil
            }
            try require(desktop.hasQuickCaptureWindow() && desktop.matchingElements("Open Editor") == 1,
                        "Expected one fixed capture result after both Enter presses.")
        default:
            throw E2EFailure("Unknown case \(id).")
        }
    }

    func startScroll() throws {
        try desktop.press("Scrolling Capture (S)")
        _ = try desktop.wait("first scrolling frame", timeout: 10) {
            desktop.element("Scroll down in the selection. Enter to finish.")
        }
    }

    func dimension(_ label: String) throws -> Int {
        let field = try desktop.wait(label) { desktop.element(label) }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(field, kAXValueAttribute as CFString, &value) == .success,
              let text = value as? String, let number = Int(text) else {
            throw E2EFailure("Cannot read \(label).")
        }
        return number
    }

    func setDimension(_ label: String, digits: [Int]) throws {
        let field = try desktop.wait(label) { desktop.element(label) }
        try desktop.click(desktop.center(of: field))
        try desktop.key(kVK_ANSI_A, flags: .maskCommand)
        for digit in digits { try desktop.key(digit) }
        try desktop.key(kVK_Return)
    }

    func copySelection() throws -> CGImage {
        let pasteboard = NSPasteboard.general
        let before = pasteboard.changeCount
        try desktop.press("Copy")
        return try desktop.wait("new image on clipboard") {
            guard pasteboard.changeCount != before else { return nil }
            for type: NSPasteboard.PasteboardType in [.png, .tiff] {
                if let bytes = pasteboard.data(forType: type),
                   let source = CGImageSourceCreateWithData(bytes as CFData, nil),
                   let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
                    desktop.artifacts.recordExport(image)
                    return image
                }
            }
            return nil
        }
    }

    func global(_ point: CGPoint) -> CGPoint {
        CGPoint(x: desktop.region.minX + point.x, y: desktop.region.minY + point.y)
    }

    func mark(from start: CGPoint, to end: CGPoint) throws {
        try desktop.drag(from: global(start), to: global(end))
    }

    func sample(_ image: CGImage, at point: CGPoint) throws -> [UInt8] {
        try pixel(image, x: Int(point.x / desktop.region.width * CGFloat(image.width)),
                  y: Int(point.y / desktop.region.height * CGFloat(image.height)))
    }

    func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw E2EFailure(message) }
    }
}
