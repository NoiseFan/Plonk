import AppKit
import Carbon.HIToolbox

extension ShotCases {
    func capturePermission(_ id: String) throws {
        let screenRecording = id == "PERM-01"
        let permission = screenRecording ? "screen-recording" : "input-events"
        guard ProcessInfo.processInfo.environment["PLONK_E2E_DENIED_PERMISSION"] == permission else {
            throw E2EBlocked("In a dedicated permission-test session, deny Plonk \(permission), then set PLONK_E2E_DENIED_PERMISSION=\(permission).")
        }

        let baseline = desktop.windowCount()
        defer { desktop.dismissCapture(above: baseline) }
        if screenRecording {
            _ = try desktop.wait("fixture focus") { NSApp.isActive ? true : nil }
            try desktop.key(kVK_ANSI_S, flags: [.maskControl, .maskAlternate])
            _ = try desktop.wait("capture permission failure feedback", timeout: 8) {
                desktop.element("Could not capture the screen. Check Screen Recording access.")
            }
        } else {
            try selectRegion()
            try desktop.press("Scrolling Capture (S)")
            _ = try desktop.wait("scroll permission failure feedback") {
                desktop.element("Grant Plonk Accessibility access to start scrolling capture.")
            }
        }
    }
}
