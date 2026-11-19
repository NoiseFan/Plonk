import AppKit
import ApplicationServices
import Carbon.HIToolbox

extension ShotCases {
    func fixedCapture(_ id: String) throws {
        let screen = id == "CAP-04"
        try openCaptureSettings()
        defer {
            if (try? desktop.nativeCaptureRunning()) == true { try? desktop.key(kVK_Escape) }
            desktop.dismissCapture(above: 0)
        }
        try desktop.press(screen ? "Capture Whole Screen" : "Capture Window")
        if !screen {
            _ = try desktop.wait("native window picker") {
                (try? desktop.nativeCaptureRunning()) == true ? true : nil
            }
            if id == "CAP-05" {
                try desktop.key(kVK_Escape)
                _ = try desktop.wait("native picker to exit") {
                    (try? desktop.nativeCaptureRunning()) == false ? true : nil
                }
                _ = try desktop.wait("settings to return") { desktop.element("Capture Window") }
                try require(desktop.element("Selection Width") == nil, "Cancel opened a capture.")
                return
            }
            let region = desktop.region
            let center = CGPoint(x: region.midX, y: region.midY)
            try desktop.mouse(.mouseMoved, at: center)
            try desktop.click(center)
        }

        _ = try desktop.wait("fixed capture toolbar") { desktop.element("Open Editor") }
        let image = try copySelection()
        if screen {
            let width = CGDisplayPixelsWide(CGMainDisplayID())
            let height = CGDisplayPixelsHigh(CGMainDisplayID())
            try require(image.width == width && image.height == height,
                        "Capture does not match the primary display's pixel dimensions.")
        } else {
            let backingFrame = desktop.fixture.convertToBacking(desktop.fixture.frame)
            let sample = try pixel(image, x: image.width / 2, y: image.height / 2)
            try require(abs(CGFloat(image.width) - backingFrame.width) <= 2
                        && Int(sample[1]) > Int(sample[0]) + 50 && Int(sample[2]) > Int(sample[0]) + 50,
                        "Window capture does not match the temporary fixture.")
        }
    }

    func directEditorCapture() throws {
        try openCaptureSettings()
        try chooseCaptureDestination("Open Editor")
        defer {
            desktop.dismissCapture(above: 1)
            try? openCaptureSettings()
            try? chooseCaptureDestination("Quick Actions")
        }
        try desktop.press("Capture Region")
        _ = try desktop.wait("native region picker") {
            (try? desktop.nativeCaptureRunning()) == true ? true : nil
        }
        defer {
            if (try? desktop.nativeCaptureRunning()) == true { try? desktop.key(kVK_Escape) }
        }
        let region = desktop.region
        try desktop.drag(from: region.origin, to: CGPoint(x: region.maxX, y: region.maxY))
        _ = try desktop.wait("independent editor") { () -> AXUIElement? in
            guard desktop.element("Selection Width") == nil else { return nil }
            return desktop.element("Undo")
        }
    }

    private func chooseCaptureDestination(_ choice: String) throws {
        let picker = try desktop.wait("After Capture picker") {
            desktop.element("After Capture", role: kAXPopUpButtonRole)
        }
        guard AXUIElementPerformAction(picker, kAXPressAction as CFString) == .success else {
            throw E2EFailure("Cannot open capture destination picker.")
        }
        let option = try desktop.wait(choice) { desktop.element(choice, role: kAXMenuItemRole) }
        guard AXUIElementPerformAction(option, kAXPressAction as CFString) == .success else {
            throw E2EFailure("Cannot select capture destination \(choice).")
        }
    }

    func selectRegion() throws {
        _ = try desktop.wait("fixture focus") { NSApp.isActive ? true : nil }
        let region = desktop.region
        try desktop.mouse(.mouseMoved, at: CGPoint(x: region.midX, y: region.midY))
        try desktop.key(kVK_ANSI_S, flags: [.maskControl, .maskAlternate])
        _ = try desktop.wait("region capture overlay") { desktop.hasQuickCaptureWindow() ? true : nil }
        try desktop.drag(from: region.origin, to: CGPoint(x: region.maxX, y: region.maxY))
    }

    func openCaptureSettings() throws {
        guard let bundle = desktop.plonk.bundleURL else { throw E2EFailure("Plonk bundle URL unavailable.") }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: bundle, configuration: configuration) { _, _ in }
        let target = try desktop.wait("screenshot settings") {
            desktop.element("Capture Window") ?? desktop.element("Screenshot")
        }
        if desktop.element("Capture Window") == nil {
            do { try desktop.click(desktop.center(of: target)) }
            catch { throw E2EFailure("Screenshot settings sidebar could not be opened: \(error)") }
        }
        _ = try desktop.wait("screenshot controls") { desktop.element("Capture Window") }
    }
}
