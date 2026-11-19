import AppKit

extension ShotCases {
    func blueSelectionAccent() throws {
        guard #available(macOS 14.0, *), CGPreflightScreenCaptureAccess() else {
            throw E2EBlocked("The test driver needs macOS 14 and Screen Recording access to inspect the selection accent.")
        }
        let config = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Plonk/config.json")
        guard let bytes = try? Data(contentsOf: config),
              let settings = (try? JSONSerialization.jsonObject(with: bytes)) as? [String: Any],
              let appearance = settings["appearance"] as? [String: Any],
              (appearance["accentHex"] as? String)?.uppercased() == "#0077F6" else {
            throw E2EBlocked("Set the test session's Plonk appearance to the blue accent before running UI-02.")
        }
        let baseline = desktop.windowCount()
        defer { desktop.dismissCapture(above: baseline) }
        try selectRegion()
        _ = try desktop.wait("selection outline") { desktop.element("Selection Width") }
        let image = try captureFixtureRegion()
        let pixels = try [3, 5, 7, 9].map { try sample(image, at: CGPoint(x: $0, y: 1)) }
        let blue = pixels.filter { $0[0] < 30 && (85...155).contains($0[1]) && $0[2] > 205 }
        try require(blue.count >= 2, "Selection corner did not use the configured blue.")
    }

    func blueSwatchIsFirst() throws {
        try openCaptureSettings()
        let appearance = try desktop.wait("Appearance navigation row") { desktop.element("Appearance") }
        try desktop.click(desktop.center(of: appearance))
        let swatches = ["#0077F6", "#62756C", "#B16D55", "#A98543", "#70879A",
                        "#818B61", "#9B7370", "#6D7775", "#8B93A6"]
        let positions = try swatches.map { hex in
            let button = try desktop.wait("accent swatch \(hex)") { desktop.element(hex) }
            return try desktop.center(of: button)
        }
        guard let blue = positions.first else { throw E2EFailure("Blue accent swatch is missing.") }
        try require(positions.dropFirst().allSatisfy { $0.x > blue.x && abs($0.y - blue.y) < 2 },
                    "Blue should be the leftmost accent swatch.")
    }
}
