import AppKit
import ApplicationServices
import Carbon.HIToolbox

extension ShotCases {
    func globalShortcutSuspension() throws {
        let shortcut: CGEventFlags = [.maskControl, .maskAlternate]
        let prompt = "Run a command, or say what you want done"
        try desktop.key(kVK_ANSI_A, flags: shortcut)
        _ = try desktop.wait("command palette before capture") { desktop.element(prompt) }
        try desktop.key(kVK_Escape)
        _ = try desktop.wait("command palette to close") { desktop.element(prompt) == nil ? true : nil }
        desktop.activateFixture()
        try selectRegion()
        _ = try desktop.wait("selection ready") { desktop.element("Selection Width") }
        let fixtureFrame = desktop.fixture.frame
        try desktop.key(kVK_ANSI_A, flags: shortcut)
        try desktop.key(kVK_LeftArrow, flags: shortcut)
        let deadline = Date(timeIntervalSinceNow: 0.75)
        repeat {
            try require(desktop.element(prompt) == nil, "The global command palette opened during capture.")
            try require(desktop.fixture.frame == fixtureFrame, "The fixture moved during capture.")
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        } while deadline.timeIntervalSinceNow > 0
    }

    func focusCase(_ id: String, baseline: Int) throws {
        if id == "FOCUS-04" {
            try desktop.key(kVK_Escape)
            _ = try desktop.wait("capture to close") { !desktop.hasQuickCaptureWindow() && desktop.windowCount() <= baseline ? true : nil }
            desktop.activateFixture()
            let before = desktop.fixture.frame
            defer { desktop.fixture.setFrame(before, display: true) }
            _ = try desktop.wait("fixture focus") { NSApp.isActive ? true : nil }
            try desktop.key(kVK_LeftArrow, flags: [.maskControl, .maskAlternate])
            _ = try desktop.wait("fixture to move to the screen's left edge") {
                guard let area = desktop.fixture.screen?.visibleFrame,
                      desktop.fixture.frame != before,
                      abs(desktop.fixture.frame.minX - area.minX) <= 40 else { return nil as Bool? }
                return true
            }
            return
        }
        if id == "FOCUS-05" {
            try desktop.switchApplication()
            _ = try desktop.wait("macOS app switcher") {
                NSWorkspace.shared.frontmostApplication?.processIdentifier == desktop.plonk.processIdentifier
                    ? nil : true
            }
            return
        }
        let tools = [
            "FOCUS-01-line": (kVK_ANSI_3, "Line"),
            "FOCUS-01-spotlight": (kVK_ANSI_6, "Spotlight"),
            "FOCUS-01-step": (kVK_ANSI_8, "Step Number"),
            "FOCUS-01-mosaic": (kVK_ANSI_9, "Mosaic"),
            "FOCUS-01-redact": (kVK_ANSI_0, "Opaque Redaction"),
        ]
        if let (key, label) = tools[id] {
            try desktop.key(key)
            _ = try desktop.wait("\(label) to be selected") {
                guard let button = desktop.element(label),
                      desktop.attribute(button, kAXValueAttribute) as? NSNumber == 1 else { return nil as Bool? }
                return true
            }
            return
        }

        switch id {
        case "FOCUS-02-width":
            let field = try desktop.wait("Selection Width") { desktop.element("Selection Width") }
            try desktop.click(desktop.center(of: field))
        case "FOCUS-02-text":
            try desktop.key(kVK_ANSI_7)
            try desktop.click(global(CGPoint(x: 130, y: 100)))
        case "FOCUS-02-filename":
            try desktop.press("Save As")
            _ = try desktop.wait("save sheet") { desktop.hasSheet() ? true : nil }
        default:
            throw E2EFailure("Unknown focus case \(id).")
        }
        _ = try desktop.wait("text input to gain focus") { desktop.focusedTextField() }
        try desktop.key(kVK_ANSI_A, flags: .maskCommand)
        try desktop.key(kVK_ANSI_9)
        _ = try desktop.wait("focused input to receive tool key") {
            guard let focused = desktop.focusedTextField(),
                  desktop.attribute(focused, kAXValueAttribute) as? String == "9" else { return nil as Bool? }
            return true
        }
        try desktop.key(kVK_Escape)
    }
}
