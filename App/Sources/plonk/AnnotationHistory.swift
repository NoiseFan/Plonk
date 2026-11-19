import CoreGraphics

struct AnnotationHistory {
    private struct Edit {
        let index: Int
        let before: Annotation?
        let after: Annotation?

        func rebased(to crop: CGRect) -> Self {
            Self(index: index, before: before?.rebased(to: crop), after: after?.rebased(to: crop))
        }
    }

    private(set) var annotations: [Annotation] = []
    private var undoStack: [Edit] = []
    private var redoStack: [Edit] = []
    private(set) var live: Annotation?
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func begin(_ kind: Annotation.Kind, at point: CGPoint, color: Int, width: Double,
                        mosaicBlockSize: Double? = nil) {
        live = Annotation(kind: kind, points: [point], colorIndex: color, width: width,
                          mosaicBlockSize: mosaicBlockSize)
    }

    mutating func drag(to point: CGPoint) {
        guard var annotation = live, let start = annotation.points.first else { return }
        if annotation.kind.tracksEveryPoint {
            annotation.points.append(point)
        } else {
            annotation.points = [start, point]
        }
        live = annotation
    }

    mutating func end(rendered: Annotation? = nil) {
        defer { live = nil }
        guard let live = rendered ?? live, live.points.count > 1,
              !live.kind.usesSourcePixels || rendered != nil else { return }
        if live.kind == .spotlight, live.boundingRect(in: CGSize(width: 1, height: 1)).isEmpty { return }
        append(live)
    }

    mutating func append(_ annotation: Annotation) {
        record(Edit(index: annotations.count, before: nil, after: annotation))
    }

    @discardableResult
    mutating func addStep(at point: CGPoint, color: Int, diameter: Double) -> Annotation {
        let number = (annotations.compactMap(\.stepNumber).max() ?? 0) + 1
        let mark = Annotation(kind: .step, points: [point], colorIndex: color, width: diameter, stepNumber: number)
        append(mark)
        return mark
    }

    mutating func editStep(_ original: Annotation, replacement: Annotation?) {
        guard original.kind == .step, let index = annotations.firstIndex(of: original), original != replacement else {
            return
        }
        record(Edit(index: index, before: original, after: replacement))
    }

    private mutating func record(_ edit: Edit) {
        apply(edit, reversed: false)
        undoStack.append(edit)
        redoStack.removeAll()
    }

    mutating func undo() {
        guard let edit = undoStack.popLast() else { return }
        apply(edit, reversed: true)
        redoStack.append(edit)
    }

    mutating func redo() {
        guard let edit = redoStack.popLast() else { return }
        apply(edit, reversed: false)
        undoStack.append(edit)
    }

    private mutating func apply(_ edit: Edit, reversed: Bool) {
        let before = reversed ? edit.after : edit.before
        let after = reversed ? edit.before : edit.after
        let end = edit.index + (before == nil ? 0 : 1)
        annotations.replaceSubrange(edit.index..<end, with: after.map { [$0] } ?? [])
    }

    func rebased(to crop: CGRect) -> Self {
        Self(annotations: annotations.map { $0.rebased(to: crop) },
             undoStack: undoStack.map { $0.rebased(to: crop) },
             redoStack: redoStack.map { $0.rebased(to: crop) })
    }
}
