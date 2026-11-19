import AppKit
import ApplicationServices
import Carbon.HIToolbox

extension ShotCases {
    func waitForEnabledAction(_ label: String) throws {
        _ = try desktop.wait("enabled \(label) action") {
            guard let action = desktop.element(label),
                  desktop.attribute(action, kAXEnabledAttribute) as? Bool == true else { return nil as Bool? }
            return true
        }
    }

    func resizeSelection(corner: Bool) throws {
        let width = try dimension("Selection Width")
        let height = try dimension("Selection Height")
        let region = desktop.region
        let horizontalDelta = 40.0
        let verticalDelta = corner ? 30.0 : 0.0
        let edge = CGPoint(x: region.maxX, y: corner ? region.maxY : region.midY)
        let target = CGPoint(x: edge.x + horizontalDelta, y: edge.y + verticalDelta)
        try desktop.drag(from: edge, to: target)
        let scale = desktop.fixture.backingScaleFactor
        let expectedWidth = width + Int((horizontalDelta * scale).rounded())
        let expectedHeight = height + Int((verticalDelta * scale).rounded())
        let actualWidth = try dimension("Selection Width")
        let actualHeight = try dimension("Selection Height")
        try require(abs(actualWidth - expectedWidth) <= 1 && abs(actualHeight - expectedHeight) <= 1,
                    "Expected resize to \(expectedWidth) × \(expectedHeight), got \(actualWidth) × \(actualHeight).")
    }

    func verifySelectionRuler(in image: CGImage) throws {
        let scale = desktop.fixture.backingScaleFactor
        let row = image.height - Int(20 * scale)
        let left = Int(28 * scale)
        let right = Int(36 * scale)
        for (column, expected) in [(left - 2, false), (left + 2, true), (right - 2, true), (right + 2, false)] {
            let sample = try pixel(image, x: column, y: row)
            let isRuler = sample[0] > 230 && sample[1] < 25 && sample[2] > 230
            try require(isRuler == expected, "Unexpected reference stripe edge at output pixel \(column), \(row).")
        }
    }

    func basicMarkup(_ tool: String) throws {
        let tools = [
            "rectangle": kVK_ANSI_1, "ellipse": kVK_ANSI_2, "arrow": kVK_ANSI_4,
            "pen": kVK_ANSI_5, "text": kVK_ANSI_7, "line": kVK_ANSI_3,
        ]
        guard let key = tools[tool] else { throw E2EFailure("Unknown markup tool \(tool).") }
        let start = CGPoint(x: 80, y: 65)
        let end = CGPoint(x: 240, y: 155)
        try desktop.key(key)
        if tool == "text" {
            try desktop.click(global(start))
            try desktop.type("E2E")
            try desktop.key(kVK_Return)
        } else {
            try mark(from: start, to: end)
        }
        let image = try copySelection()
        let reference = try sample(image, at: CGPoint(x: 30, y: 30))
        let probes: [CGPoint]
        switch tool {
        case "rectangle":
            probes = [CGPoint(x: 80, y: 110), CGPoint(x: 160, y: 65)]
        case "ellipse":
            probes = [CGPoint(x: 160, y: 65), CGPoint(x: 240, y: 110)]
        case "text":
            probes = (0..<75).flatMap { x in
                (0..<35).map { y in CGPoint(x: start.x + CGFloat(x), y: start.y + CGFloat(y)) }
            }
        default:
            probes = [CGPoint(x: 120, y: 87.5), CGPoint(x: 200, y: 132.5)]
        }
        let marked = try probes.filter { try sample(image, at: $0) != reference }
        try require(tool == "text" ? marked.count >= 8 : marked.count == probes.count,
                    "Expected \(tool) at its reference points.")
    }

    func moveSelection() throws {
        try mark(from: CGPoint(x: 220, y: 140), to: CGPoint(x: 260, y: 140))
        let image = try copySelection()
        let pattern = try sample(image, at: CGPoint(x: 101, y: 96))
        let reference = try sample(image, at: CGPoint(x: 35, y: 35))
        let oldPattern = try sample(image, at: CGPoint(x: 175, y: 96))
        try require(pattern != reference && oldPattern == reference,
                    "Expected the fixture pattern to shift 40 points to the left inside the moved selection.")
    }

    func cropPreservesAnnotation() throws {
        try desktop.key(kVK_ANSI_0)
        try mark(from: CGPoint(x: 133, y: 88), to: CGPoint(x: 187, y: 143))
        let scale = desktop.fixture.backingScaleFactor
        let targetWidth = Int(230 * scale)
        let keys = [kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4,
                    kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        let digits = String(targetWidth).compactMap { $0.wholeNumberValue }.map { keys[$0] }
        try setDimension("Selection Width", digits: digits)
        let image = try copySelection()
        for point in [CGPoint(x: 138, y: 100), CGPoint(x: 180, y: 131)] {
            let marked = try pixel(image, x: Int(point.x * scale), y: Int(point.y * scale))
            try require(marked == [0, 0, 0, 255], "Redaction shifted relative to the source on crop.")
        }
    }

    func mosaic() throws {
        try desktop.key(kVK_ANSI_9)
        try mark(from: CGPoint(x: 135, y: 90), to: CGPoint(x: 185, y: 140))
        let image = try copySelection()
        let samples = try (0..<20).map { offset in
            try sample(image, at: CGPoint(x: 150 + offset, y: 112))
        }
        let transitions = zip(samples, samples.dropFirst()).filter { $0 != $1 }.count
        let containsBlendedPixels = samples.contains { pixel in
            pixel[0] > 20 && pixel[0] < 235 && abs(Int(pixel[0]) - Int(pixel[1])) < 15
        }
        try require(transitions < 6 && containsBlendedPixels, "Expected the original checkerboard to become pixel blocks.")
    }
}
