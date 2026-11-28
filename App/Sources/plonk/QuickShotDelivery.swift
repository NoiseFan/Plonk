import AppKit

/// What a Quick Shot does with a finished crop: copy it, save it or hand it to
/// the editor, and remember the region it came from so R can restore it.
@MainActor
final class QuickShotDelivery {
    private let folder: () -> String
    private let annotation: ShotAnnotationState
    private let rememberRegion: (ShotRegionRecord) -> Void
    private let onEditor: (NSImage, AnnotationHistory, ShotAnnotationState) -> Void
    private let onFinish: (Bool, String?) -> Void
    /// Ends the session; the argument says whether focus goes back to the previous app.
    var close: (Bool) -> Void = { _ in }
    var isOpen: () -> Bool = { false }
    var remembersRegion = true

    init(folder: @escaping () -> String, annotation: ShotAnnotationState,
         rememberRegion: @escaping (ShotRegionRecord) -> Void,
         onEditor: @escaping (NSImage, AnnotationHistory, ShotAnnotationState) -> Void,
         onFinish: @escaping (Bool, String?) -> Void) {
        self.folder = folder
        self.annotation = annotation
        self.rememberRegion = rememberRegion
        self.onEditor = onEditor
        self.onFinish = onFinish
    }

    func perform(_ action: QuickShotOutput, crop: ShotCrop, in window: QuickShotWindow) {
        switch action {
        case .editor:
            remember(crop, in: window)
            close(false)
            onEditor(crop.image, crop.history, annotation)
        case .copy:
            guard let image = render(crop) else { return }
            guard ScreenshotManager.copyToClipboard(image) else {
                HUD.shared.show(.shotCopyFailed)
                return
            }
            remember(crop, in: window)
            close(true)
            onFinish(true, nil)
        case .save:
            save(crop, in: window, to: .folder(folder()))
        case .saveAs:
            guard window.attachedSheet == nil else { return }
            let panel = ShotSavePanel.make(in: folder())
            panel.beginSheetModal(for: window) { [weak self, weak window] response in
                guard let self, let window, isOpen(), response == .OK, let url = panel.url else { return }
                save(crop, in: window, to: .path(url.path))
            }
        }
    }

    private func render(_ crop: ShotCrop) -> NSImage? {
        let image = crop.rendered()
        if image == nil { HUD.shared.show(.shotEditorRenderFailed) }
        return image
    }

    private func save(_ crop: ShotCrop, in window: QuickShotWindow, to destination: ScreenshotManager.Destination) {
        guard let image = render(crop) else { return }
        guard let path = ScreenshotManager.save(image, to: destination) else {
            HUD.shared.show(.shotEditorWriteFailed)
            return
        }
        remember(crop, in: window)
        close(true)
        onFinish(false, path)
    }

    private func remember(_ crop: ShotCrop, in window: QuickShotWindow) {
        guard remembersRegion, let display = window.regionDisplay else { return }
        rememberRegion(ShotRegionRecord(display: display, rect: crop.rect))
    }
}
