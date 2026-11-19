import AppKit

extension QuickShotCanvas {
    func showCaptureFeedback(_ message: LocalizedStringResource) {
        controls.showFeedback(message)
        refresh()
    }

    func beginRecognition() -> Int? {
        guard !recognizing else { return nil }
        recognizing = true
        recognitionToken += 1
        showCaptureFeedback(.shotRecognizing)
        return recognitionToken
    }

    func finishRecognition(_ result: Result<[TextExtractor.Line], Error>, token: Int) {
        guard recognitionToken == token else { return }
        recognizing = false
        switch result {
        case .success(let lines):
            let selection = ShotTextSelection(lines: lines)
            if selection.glyphs.isEmpty {
                controls.showFeedback(.hudNoTextFound)
            } else {
                let view = ShotTextSelectionView(frame: markupClip, selection: selection) { [weak self] in
                    self?.controls.showFeedback(.shotCopiedRecognizedText)
                    self?.refresh()
                }
                view.autoresizingMask = [.width, .height]
                addSubview(view, positioned: .below, relativeTo: controls.dimensions)
                recognizedText = view
                setMarkupVisible(false)
                window?.makeFirstResponder(view)
                controls.showFeedback(.shotSelectRecognizedText)
            }
        case .failure: controls.showFeedback(.shotRecognitionFailed)
        }
        refresh()
    }

    @discardableResult
    func dismissRecognition() -> Bool {
        guard !controls.feedback.isHidden else { return false }
        recognizing = false
        recognitionToken += 1
        if let view = recognizedText {
            if window?.firstResponder === view { window?.makeFirstResponder(self) }
            view.removeFromSuperview()
            recognizedText = nil
            setMarkupVisible(true)
        }
        controls.showFeedback(nil)
        return true
    }
}
