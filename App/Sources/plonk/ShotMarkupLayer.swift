import SwiftUI

struct ShotMarkupLayer: View {
    var history = AnnotationHistory()
    var imageRect = CGRect.zero
    var clip = CGRect.zero
    var selectedStep: UUID?
    var movedStep: Annotation?
    var renderedMosaic: Annotation?

    var body: some View {
        Canvas { context, _ in
            context.clip(to: Path(clip))
            context.translateBy(x: imageRect.minX, y: imageRect.minY)
            let marks = history.annotations.map { mark in
                movedStep?.id == mark.id ? movedStep ?? mark : mark
            }
            AnnotationRenderer.draw(marks, live: renderedMosaic ?? (history.live?.kind.usesSourcePixels == true ? nil : history.live), in: &context, size: imageRect.size)
            if let selected = marks.first(where: { $0.id == selectedStep }) {
                let ring = selected.stepRect(in: imageRect.size).insetBy(dx: -2, dy: -2)
                context.stroke(Path(ellipseIn: ring), with: .color(.white), lineWidth: 2)
            }
        }
    }
}
