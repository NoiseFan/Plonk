import AppKit
import Carbon.HIToolbox

enum ShotKeyCommand: Equatable {
    case cancel
    case copy
    case save
    case undo
    case redo
    case selectDisplay
    case restoreRegion
    case copyColor
    case zoomMagnifier(increasing: Bool)

    /// What the toolbar would do for this key; the session handles the rest.
    var toolbarAction: QuickShotToolbar.Action? {
        switch self {
        case .cancel: .cancel
        case .copy: .output(.copy)
        case .save: .output(.save)
        case .undo: .undo
        case .redo: .redo
        case .selectDisplay, .restoreRegion, .copyColor, .zoomMagnifier: nil
        }
    }

    init?(hotkey: Hotkey) {
        var flags: NSEvent.ModifierFlags = []
        if hotkey.command { flags.insert(.command) }
        if hotkey.shift { flags.insert(.shift) }
        if hotkey.option { flags.insert(.option) }
        if hotkey.control { flags.insert(.control) }
        self.init(keyCode: Int(hotkey.keyCode), characters: nil, flags: flags, repeating: false)
    }

    /// `characters` is the event's `charactersIgnoringModifiers`. On a Latin layout the
    /// typed letter decides, as macOS menus do. Other layouts use the US key position
    /// for letter shortcuts.
    init?(keyCode: Int, characters: String?, flags: NSEvent.ModifierFlags, repeating: Bool) {
        guard !repeating else { return nil }
        let modifiers = flags.intersection([.command, .shift, .option, .control])
        switch (keyCode, modifiers) {
        case (kVK_Escape, []): self = .cancel
        case (kVK_Return, []), (kVK_ANSI_KeypadEnter, []): self = .copy
        default:
            switch (characters, modifiers) {
            case ("+", []), ("+", .shift), ("=", []), ("=", .shift):
                self = .zoomMagnifier(increasing: true)
                return
            case ("-", []):
                self = .zoomMagnifier(increasing: false)
                return
            default: break
            }
            switch (Self.letter(keyCode: keyCode, characters: characters), modifiers) {
            case ("f", []): self = .selectDisplay
            case ("r", []): self = .restoreRegion
            case ("s", .command): self = .save
            case ("z", .command): self = .undo
            case ("z", [.command, .shift]): self = .redo
            case ("c", []): self = .copyColor
            default: return nil
            }
        }
    }

    private static func letter(keyCode: Int, characters: String?) -> Character? {
        if let typed = characters?.lowercased(), typed.count == 1, let char = typed.first,
           char.isASCII, char.isLetter {
            return char
        }
        switch keyCode {
        case kVK_ANSI_C: return "c"
        case kVK_ANSI_F: return "f"
        case kVK_ANSI_R: return "r"
        case kVK_ANSI_S: return "s"
        case kVK_ANSI_Z: return "z"
        default: return nil
        }
    }
}
