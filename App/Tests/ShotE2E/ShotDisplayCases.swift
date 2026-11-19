import AppKit

extension ShotCases {
    func displayCase(_ id: String) throws {
        guard let primary = NSScreen.screens.first,
              let secondary = NSScreen.screens.dropFirst().first(where: {
                  id == "DISPLAY-02" || $0.backingScaleFactor != primary.backingScaleFactor
              }) else {
            throw E2EBlocked(id == "DISPLAY-02"
                ? "Connect a secondary display for the disconnect test."
                : "Connect a secondary display with a different scaling factor.")
        }
        let secondaryDesktop = try Desktop(plonk: desktop.plonk, artifacts: desktop.artifacts, screen: secondary)
        defer { secondaryDesktop.fixture.orderOut(nil) }
        let secondaryCases = ShotCases(desktop: secondaryDesktop)
        if id.hasPrefix("DISPLAY-01-") {
            desktop.fixture.orderOut(nil)
            try secondaryCases.run(String(id.dropFirst("DISPLAY-01-".count)))
            return
        }

        guard ProcessInfo.processInfo.environment["PLONK_E2E_DISCONNECT_DISPLAY"] == "1" else {
            throw E2EBlocked("Run DISPLAY-02 with PLONK_E2E_DISCONNECT_DISPLAY=1 and a test operator at the secondary display.")
        }
        let baseline = desktop.windowCount()
        defer { secondaryDesktop.dismissCapture(above: baseline) }
        secondaryDesktop.showFixture(scrolling: true, recognizing: false, multiline: false,
                                     patterned: false, longScroll: false)
        try secondaryCases.selectRegion()
        try secondaryCases.startScroll()
        let identifier = NSDeviceDescriptionKey("NSScreenNumber")
        guard let secondaryID = secondary.deviceDescription[identifier] as? NSNumber else {
            throw E2EBlocked("The secondary display has no stable identifier.")
        }
        print("DISPLAY-02: Disconnect the secondary display now.")
        _ = try desktop.wait("secondary display to be disconnected", timeout: 45) {
            NSScreen.screens.contains(where: { $0.deviceDescription[identifier] as? NSNumber == secondaryID }) ? nil : true
        }
        _ = try desktop.wait("capture to close on display configuration change") {
            desktop.hasQuickCaptureWindow() ? nil : true
        }
    }
}
