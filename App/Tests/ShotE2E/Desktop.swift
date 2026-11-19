import AppKit
import ApplicationServices
import Carbon.HIToolbox

struct E2EFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) { self.description = description }
}

final class Desktop {
    let plonk: NSRunningApplication
    let artifacts: ShotArtifacts
    let fixture: NSWindow
    let region: CGRect
    private let ruler = NSView(frame: CGRect(x: 128, y: 100, width: 8, height: 80))
    private let pattern = NSView(frame: CGRect(x: 100, y: 100, width: 360, height: 230))
    private let scroll = NSScrollView()
    private let secondText = NSTextField(labelWithString: "SECOND LINE 719")
    private let text = NSTextField(labelWithString: "PLONK OCR 4827")

    init(plonk: NSRunningApplication, artifacts: ShotArtifacts, screen requestedScreen: NSScreen? = nil) throws {
        self.plonk = plonk
        self.artifacts = artifacts
        guard let screen = requestedScreen ?? NSScreen.main, screen.visibleFrame.width >= 720, screen.visibleFrame.height >= 520 else {
            throw E2EFailure("A desktop of at least 720 × 520 points is required.")
        }
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 620, height: 440),
                              styleMask: [.titled], backing: .buffered, defer: false)
        fixture = window
        window.title = "Plonk E2E Fixture"
        window.setFrameOrigin(CGPoint(x: screen.visibleFrame.midX - window.frame.width / 2,
                                      y: screen.visibleFrame.midY - window.frame.height / 2))
        let canvas = NSView(frame: CGRect(x: 0, y: 0, width: 620, height: 440))
        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = NSColor(srgbRed: 0.2, green: 0.75, blue: 0.85, alpha: 1).cgColor
        window.contentView = canvas
        text.font = .monospacedSystemFont(ofSize: 25, weight: .bold)
        text.textColor = .black
        text.frame = CGRect(x: 145, y: 200, width: 280, height: 34)
        canvas.addSubview(text)
        secondText.font = text.font
        secondText.textColor = .black
        secondText.frame = CGRect(x: 145, y: 160, width: 310, height: 34)
        canvas.addSubview(secondText)
        for row in 0..<20 {
            for column in 0..<20 {
                let cell = NSView(frame: CGRect(x: 140 + column * 2, y: 95 + row * 2, width: 2, height: 2))
                cell.wantsLayer = true
                cell.layer?.backgroundColor = (row + column).isMultiple(of: 2)
                    ? NSColor.white.cgColor : NSColor.black.cgColor
                pattern.addSubview(cell)
            }
        }
        pattern.isHidden = true
        canvas.addSubview(pattern)
        ruler.wantsLayer = true
        ruler.layer?.backgroundColor = NSColor(srgbRed: 1, green: 0, blue: 1, alpha: 1).cgColor
        canvas.addSubview(ruler)
        scroll.frame = canvas.bounds
        scroll.drawsBackground = false
        scroll.isHidden = true
        canvas.addSubview(scroll)
        let frame = window.convertToScreen(CGRect(x: 100, y: 100, width: 360, height: 230))
        region = CGRect(x: frame.minX, y: NSScreen.screens[0].frame.maxY - frame.maxY,
                        width: frame.width, height: frame.height)
    }

    func showFixture(scrolling: Bool, recognizing: Bool, multiline: Bool, patterned: Bool, longScroll: Bool, measuring: Bool = false) {
        ruler.isHidden = !measuring
        pattern.isHidden = !patterned
        text.isHidden = !recognizing
        secondText.isHidden = !multiline
        scroll.isHidden = !scrolling
        if scrolling {
            let rowCount = longScroll ? Int(ceil(26_000 / (25 * fixture.backingScaleFactor))) + 24 : 40
            scroll.documentView = Self.scrollDocument(rowCount: rowCount)
            setScrollOffset(0)
        }
        activateFixture()
    }

    func activateFixture() {
        NSApp.activate(ignoringOtherApps: true)
        fixture.makeKeyAndOrderFront(nil)
    }

    static func stripeColor(_ index: Int) -> NSColor {
        NSColor(hue: CGFloat(index * 17 % 40) / 40, saturation: 0.7, brightness: 0.8, alpha: 1)
    }

    var maximumScrollOffset: CGFloat {
        max(0, (scroll.documentView?.frame.height ?? 0) - scroll.contentSize.height)
    }

    var scrollOffset: CGFloat { maximumScrollOffset - scroll.contentView.bounds.minY }

    func setScrollOffset(_ offset: CGFloat) {
        guard let document = scroll.documentView else { return }
        scroll.contentView.scroll(to: CGPoint(x: 0, y: document.frame.height - scroll.contentSize.height - offset))
        scroll.reflectScrolledClipView(scroll.contentView)
    }

    func wait<T>(_ description: String, timeout: TimeInterval = 5, until observe: () -> T?) throws -> T {
        artifacts.note("Wait for \(description)")
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        repeat {
            if let value = observe() { return value }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.025))
        } while ProcessInfo.processInfo.systemUptime < deadline
        throw E2EFailure("Timed out waiting for \(description).")
    }

    func key(_ code: Int, flags: CGEventFlags = []) throws {
        artifacts.note("Key code \(code), modifiers \(flags.rawValue)")
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(code), keyDown: down) else {
                throw E2EFailure("Unable to create key event.")
            }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }

    func switchApplication() throws {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Command), keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_Command), keyDown: false) else {
            throw E2EFailure("Unable to simulate Command-Tab.")
        }
        down.type = .flagsChanged
        down.flags = .maskCommand
        up.type = .flagsChanged
        up.flags = []
        down.post(tap: .cghidEventTap)
        defer { up.post(tap: .cghidEventTap) }
        try key(kVK_Tab, flags: .maskCommand)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
    }

    func mouse(_ type: CGEventType, at position: CGPoint) throws {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: position,
                                  mouseButton: .left) else {
            throw E2EFailure("Unable to create mouse event.")
        }
        event.post(tap: .cghidEventTap)
    }

    func click(_ position: CGPoint) throws {
        artifacts.note("Click at \(position)")
        try mouse(.leftMouseDown, at: position)
        try mouse(.leftMouseUp, at: position)
    }

    func drag(from start: CGPoint, to end: CGPoint) throws {
        artifacts.note("Drag from \(start) to \(end)")
        try mouse(.leftMouseDown, at: start)
        for step in 1...12 {
            let fraction = CGFloat(step) / 12
            try mouse(.leftMouseDragged, at: CGPoint(x: start.x + (end.x - start.x) * fraction,
                                                     y: start.y + (end.y - start.y) * fraction))
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        try mouse(.leftMouseUp, at: end)
    }

    func scrollDown(at position: CGPoint) throws {
        try mouse(.mouseMoved, at: position)
        guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                                  wheel1: -60, wheel2: 0, wheel3: 0) else {
            throw E2EFailure("Unable to create scroll event.")
        }
        event.location = position
        event.post(tap: .cghidEventTap)
    }

    func element(_ label: String, role: String? = nil) -> AXUIElement? {
        let app = AXUIElementCreateApplication(plonk.processIdentifier)
        let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
        return windows.lazy.compactMap { self.find(label, role: role, under: $0, depth: 0) }.first
    }

    func paste(_ text: String) throws {
        let clipboard = NSPasteboard.general
        clipboard.clearContents()
        guard clipboard.setString(text, forType: .string) else {
            throw E2EFailure("Unable to prepare text input on the clipboard.")
        }
        try key(kVK_ANSI_V, flags: .maskCommand)
    }

    func type(_ text: String) throws {
        let characters = Array(text.utf16)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down) else {
                throw E2EFailure("Unable to create text input event.")
            }
            characters.withUnsafeBufferPointer {
                event.keyboardSetUnicodeString(stringLength: $0.count, unicodeString: $0.baseAddress)
            }
            event.post(tap: .cghidEventTap)
        }
    }

    func focusedTextField() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        guard let focused = attribute(system, kAXFocusedUIElementAttribute),
              CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        let element = focused as! AXUIElement
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success, pid == plonk.processIdentifier,
              attribute(element, kAXRoleAttribute) as? String == kAXTextFieldRole else { return nil }
        return element
    }

    func hasSheet() -> Bool {
        let app = AXUIElementCreateApplication(plonk.processIdentifier)
        let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
        return windows.contains { window in
            let children = attribute(window, kAXChildrenAttribute) as? [AXUIElement] ?? []
            return children.contains { attribute($0, kAXRoleAttribute) as? String == kAXSheetRole }
        }
    }

    func press(_ label: String) throws {
        artifacts.note("Press \(label)")
        let button = try wait(label) { element(label) }
        guard AXUIElementPerformAction(button, kAXPressAction as CFString) == .success else {
            throw E2EFailure("Cannot press \(label).")
        }
    }

    func center(of element: AXUIElement) throws -> CGPoint {
        guard let position = attribute(element, kAXPositionAttribute),
              let size = attribute(element, kAXSizeAttribute),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else {
            throw E2EFailure("Element has no accessible frame.")
        }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else {
            throw E2EFailure("Cannot read element frame.")
        }
        return CGPoint(x: point.x + dimensions.width / 2, y: point.y + dimensions.height / 2)
    }

    func dismissCapture(above baseline: Int) {
        for _ in 0..<3 where (hasQuickCaptureWindow() || windowCount() > baseline) && plonk.isActive {
            try? key(kVK_Escape)
            if (try? wait("capture to close", timeout: 0.5, until: {
                !self.hasQuickCaptureWindow() && self.windowCount() <= baseline ? true : nil
            })) == true { return }
        }
    }

    func nativeCaptureRunning() throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-P", String(plonk.processIdentifier), "-x", "screencapture"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    func windowCount() -> Int { plonkWindows().count }

    func hasQuickCaptureWindow() -> Bool {
        let level = Int(CGWindowLevelForKey(.screenSaverWindow))
        return plonkWindows().contains { $0[kCGWindowLayer as String] as? Int == level }
    }

    private func plonkWindows() -> [[String: Any]] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.filter { $0[kCGWindowOwnerPID as String] as? Int32 == plonk.processIdentifier }
    }

    func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value
    }
}
