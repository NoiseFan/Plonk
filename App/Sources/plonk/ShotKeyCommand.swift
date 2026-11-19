import AppKit
import Carbon.HIToolbox

enum ShotKeyCommand {
    case action(QuickShotAction)
    case select(Annotation.Kind)
    case deleteStep
    case undo
    case redo
    case cancel
    case tab(backward: Bool)

    init?(event: NSEvent, window: NSWindow, canvas: ShotMarkupCanvas) {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        let code = Int(event.keyCode)
        if code == kVK_ANSI_S, flags == .command || flags == [.command, .shift] {
            self = .action(.save(forceCopy: flags.contains(.shift)))
            return
        }
        if event.keyCode == kVK_Escape, flags.isEmpty, !(window.firstResponder is NSTextView) {
            self = .cancel
            return
        }
        guard window.firstResponder === canvas else { return nil }
        if code == kVK_ANSI_Z, flags == .command || flags == [.command, .shift] {
            self = flags.contains(.shift) ? .redo : .undo
            return
        }
        if event.keyCode == kVK_Tab, flags.isEmpty || flags == .shift {
            self = .tab(backward: flags.contains(.shift))
            return
        }
        guard flags.isEmpty else { return nil }
        switch code {
        case kVK_Return, kVK_ANSI_KeypadEnter, kVK_Space:
            self = .action(.copy)
        case kVK_Delete, kVK_ForwardDelete:
            guard canvas.canDeleteStep else { return nil }
            self = .deleteStep
        default:
            switch code {
            case kVK_ANSI_1: self = .select(.rectangle)
            case kVK_ANSI_2: self = .select(.ellipse)
            case kVK_ANSI_3: self = .select(.line)
            case kVK_ANSI_4: self = .select(.arrow)
            case kVK_ANSI_5: self = .select(.pen)
            case kVK_ANSI_6: self = .select(.spotlight)
            case kVK_ANSI_7: self = .select(.text)
            case kVK_ANSI_8: self = .select(.step)
            case kVK_ANSI_9: self = .select(.mosaic)
            case kVK_ANSI_0: self = .select(.redact)
            case kVK_ANSI_S: self = .action(.scroll)
            case kVK_ANSI_P: self = .action(.preview)
            case kVK_ANSI_O: self = .action(.recognizeText)
            case kVK_ANSI_W: self = .action(.editor)
            default: return nil
            }
        }
    }
}
