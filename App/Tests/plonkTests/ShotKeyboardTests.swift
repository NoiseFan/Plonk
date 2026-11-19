import AppKit
import Carbon.HIToolbox
import Testing
@testable import plonk

struct ShotKeyboardTests {
    @Test func suspendingHotkeysEndsHeldActionsOnce() {
        let manager = HotkeyManager()
        var suspensions = 0
        manager.onSuspend = { suspensions += 1 }
        manager.setSuspended(true)
        manager.setSuspended(true)
        #expect(suspensions == 1)
        manager.setSuspended(false)
        manager.setSuspended(true)
        #expect(suspensions == 2)
    }

    @MainActor
    @Test func screenshotKeysFollowPhysicalKeyCodes() throws {
        let canvas = ShotMarkupCanvas(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        let window = NSWindow(contentRect: canvas.frame, styleMask: .titled, backing: .buffered, defer: false)
        window.contentView = canvas
        window.makeFirstResponder(canvas)
        func event(_ code: Int, _ characters: String, _ flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
            try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags,
                                          timestamp: 0, windowNumber: window.windowNumber,
                                          context: nil, characters: characters,
                                          charactersIgnoringModifiers: characters, isARepeat: false,
                                          keyCode: UInt16(code)))
        }
        let save = try #require(ShotKeyCommand(event: event(kVK_ANSI_S, "ы", .command), window: window, canvas: canvas))
        guard case .action(.save) = save else { Issue.record("Cmd+S did not match its key code"); return }
        let undo = try #require(ShotKeyCommand(event: event(kVK_ANSI_Z, "я", .command), window: window, canvas: canvas))
        guard case .undo = undo else { Issue.record("Cmd+Z did not match its key code"); return }
        let firstTool = try #require(ShotKeyCommand(event: event(kVK_ANSI_1, "&"), window: window, canvas: canvas))
        guard case .select(.rectangle) = firstTool else { Issue.record("The first digit key did not select a tool"); return }
    }
}
