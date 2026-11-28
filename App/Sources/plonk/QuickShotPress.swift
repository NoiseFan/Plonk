import CoreGraphics

/// What a mouse-down on the Quick Actions canvas does.
enum QuickShotPress: Equatable {
    case mark
    case adjust(handle: CGPoint)
    case select
    case ignore

    /// `handle` is `ShotSelection.handle(at:of:)`, `.zero` when off every edge.
    /// A new selection drops the marks, so neither a press outside the selection
    /// nor one inside a selection covering the whole display starts one while any
    /// display still holds marks or redo history. A full-display selection has
    /// nowhere to move, so a press inside it draws a fresh region instead.
    init(handle: CGPoint, insideSelection: Bool, coversDisplay: Bool = false, drawing: Bool, marksExist: Bool) {
        if handle != .zero {
            self = .adjust(handle: handle)
        } else if insideSelection {
            if drawing {
                self = .mark
            } else {
                self = coversDisplay && !marksExist ? .select : .adjust(handle: .zero)
            }
        } else {
            self = marksExist ? .ignore : .select
        }
    }
}
