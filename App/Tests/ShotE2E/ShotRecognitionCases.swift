import AppKit
import Carbon.HIToolbox

extension ShotCases {
    func recognitionCase(_ id: String) throws {
        let ready = "Select text, then press ⌘C to copy."
        try desktop.press("Recognize and Copy Text")
        if id == "OCR-05" {
            try closePendingRecognition(ready: ready)
            return
        }
        if id == "OCR-04" {
            do {
                _ = try desktop.wait("active recognition request", timeout: 1) {
                    desktop.element("Recognizing text…")
                }
            } catch {
                throw E2EBlocked("Recognition completed before a second request could be sent during the first one.")
            }
            try desktop.press("Recognize and Copy Text")
            _ = try desktop.wait("recognition result", timeout: 15) { desktop.element(ready) }
            try require(desktop.matchingElements(ready) == 1, "Expected exactly one visible recognition result.")
            return
        }
        _ = try desktop.wait("recognition result", timeout: 15) { desktop.element(ready) }
        if id == "OCR-03" {
            try desktop.key(kVK_Escape)
            _ = try desktop.wait("recognition selection to close") { desktop.element(ready) == nil ? true : nil }
            try require(desktop.element("Selection Width") != nil, "Escape closed the capture.")
            return
        }

        let firstGlyph = CGPoint(x: 52, y: 113)
        let endOfWord = CGPoint(x: 113, y: 113)
        if id == "OCR-01" {
            guard #available(macOS 14.0, *), CGPreflightScreenCaptureAccess() else {
                throw E2EBlocked("The test driver needs macOS 14 and Screen Recording access to compare selection pixels.")
            }
            let before = try captureFixtureRegion()
            try mark(from: firstGlyph, to: endOfWord)
            let after = try captureFixtureRegion()
            let wordArea = [CGPoint(x: 57, y: 109), CGPoint(x: 83, y: 112), CGPoint(x: 106, y: 115)]
            let controls = [CGPoint(x: 155, y: 109), CGPoint(x: 83, y: 90), CGPoint(x: 83, y: 137)]
            let highlighted = try wordArea.filter { try sample(before, at: $0) != sample(after, at: $0) }
            let unrelated = try controls.filter { try sample(before, at: $0) != sample(after, at: $0) }
            try require(highlighted.count >= 2 && unrelated.isEmpty,
                        "Selection highlighting did not align with the selected word.")
            return
        }

        let multiline = id == "OCR-02-multiline"
        try mark(from: firstGlyph, to: multiline ? CGPoint(x: 264, y: 153) : endOfWord)
        let clipboard = NSPasteboard.general
        let before = clipboard.changeCount
        try desktop.key(kVK_ANSI_C, flags: .maskCommand)
        let copied = try desktop.wait("recognized text on clipboard") {
            clipboard.changeCount == before ? nil : clipboard.string(forType: .string)
        }
        let expected = multiline ? "PLONK OCR 4827\nSECOND LINE 719" : "PLONK"
        try require(copied == expected, "Unexpected recognition selection: \(copied.debugDescription).")
    }

    private func closePendingRecognition(ready: String) throws {
        let pending = "Recognizing text…"
        do {
            _ = try desktop.wait("active recognition request", timeout: 1) { desktop.element(pending) }
        } catch {
            throw E2EBlocked("Could not observe a pending recognition request before closing the session.")
        }
        try desktop.press("Cancel")
        _ = try desktop.wait("old capture to close") { desktop.hasQuickCaptureWindow() ? nil : true }
        desktop.activateFixture()
        try selectRegion()
        _ = try desktop.wait("new selection") { desktop.element("Selection Width") }
        let deadline = Date(timeIntervalSinceNow: 1.5)
        repeat {
            try require(desktop.element(ready) == nil, "The old OCR results appeared in the new capture.")
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        } while deadline.timeIntervalSinceNow > 0
        throw E2EBlocked("The desktop did not expose when the old request completed. Its completion after close could not be confirmed.")
    }
}
