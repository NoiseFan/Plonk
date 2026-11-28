import AppKit

@MainActor
final class QuickShotSession: NSObject {
    private let previousApp: NSRunningApplication?
    private let model: AppModel
    private let lastRegion: ShotRegionRecord?
    private let annotation: ShotAnnotationState
    private let delivery: QuickShotDelivery
    private var onClose: (() -> Void)?
    private var windows: [QuickShotWindow] = []
    private var keyMonitor: Any?
    private lazy var magnifier = QuickShotMagnifierTracker(windows: { [weak self] in self?.windows ?? [] },
                                                           isWaiting: { [weak self] in self?.isWaitingForSelection ?? false })
    private var pickerMonitor: Any?
    private var picker: Process?
    private var pickLocation: CGPoint?
    private var captureTask: Task<Void, Never>?

    init(previousApp: NSRunningApplication?, model: AppModel, lastRegion: ShotRegionRecord?,
         rememberRegion: @escaping (ShotRegionRecord) -> Void, folder: @escaping () -> String,
         onClose: @escaping () -> Void,
         onEditor: @escaping (NSImage, AnnotationHistory, ShotAnnotationState) -> Void,
         onFinish: @escaping (Bool, String?) -> Void) {
        self.previousApp = previousApp
        self.model = model
        self.lastRegion = lastRegion
        annotation = ShotAnnotationState(defaults: model.config.shotAnnotationStyles)
        delivery = QuickShotDelivery(folder: folder, annotation: annotation, rememberRegion: rememberRegion,
                                     onEditor: onEditor, onFinish: onFinish)
        self.onClose = onClose
        super.init()
        delivery.close = { [weak self] in self?.close(restoreFocus: $0) }
        delivery.isOpen = { [weak self] in self?.onClose != nil }
    }

    func begin(_ mode: CaptureMode, screen: NSScreen?) {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return captureFailed() }
        NotificationCenter.default.addObserver(
            self, selector: #selector(cancel), name: NSApplication.didChangeScreenParametersNotification, object: NSApp
        )
        switch mode {
        case .region:
            watchForAppSwitch()
            captureDisplays(screens)
        case .window:
            // Give the window server a turn after ordering Plonk's windows out.
            DispatchQueue.main.async { [weak self] in
                guard let self, onClose != nil else { return }
                pickWindow()
            }
        case .screen:
            guard let screen else { return captureFailed() }
            watchForAppSwitch()
            // The whole display is what F gives; it is no region worth keeping for R.
            delivery.remembersRegion = false
            captureDisplays([screen], selectingEntireDisplay: true)
        }
    }

    private func watchForAppSwitch() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(frontmostAppChanged), name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    /// Plonk's own windows stay up: the capture leaves them out, so nothing flickers.
    private func captureDisplays(_ screens: [NSScreen], selectingEntireDisplay: Bool = false) {
        let windowBounds = selectingEntireDisplay ? [] : WindowServer.screenshotWindowBounds()
        captureTask = Task { [weak self] in
            do {
                let bitmaps = try await ShotDisplayCapture.capture(screens)
                try Task.checkCancellation()
                guard let self, onClose != nil else { return }
                guard !hasSwitchedApps else { return cancelOnAppSwitch() }
                for (screen, bitmap) in zip(screens, bitmaps) {
                    let window = addWindow(for: screen, bitmap: bitmap, fixed: false)
                    let origin = CGSpace.flip(screen.frame).origin
                    window.canvas.startsOnWindow = { point in
                        let location = CGPoint(x: origin.x + point.x, y: origin.y + point.y)
                        return windowBounds.contains { $0.contains(location) }
                    }
                }
                if selectingEntireDisplay, let window = windows.first { selectEntireDisplay(in: window) }
                present()
            } catch {
                guard let self, onClose != nil else { return }
                captureFailed()
            }
        }
    }

    private func pickWindow() {
        pickerMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.pickLocation = event.cgEvent.map { CGSpace.flip($0.location) } ?? NSEvent.mouseLocation
        }
        picker = ScreenshotManager.pickWindow { [weak self] result in
            guard let self, onClose != nil else { return }
            stopPicker()
            switch result {
            case .captured(let image):
                let screen = ScreenIdentity.screen(at: pickLocation ?? NSEvent.mouseLocation)
                presentWindowCapture(image, on: screen)
            case .noImage where CGPreflightScreenCaptureAccess():
                cancel()
            default:
                captureFailed()
            }
        }
    }

    private func stopPicker() {
        if let pickerMonitor { NSEvent.removeMonitor(pickerMonitor) }
        pickerMonitor = nil
        if let picker, picker.isRunning { picker.terminate() }
        picker = nil
    }

    private func presentWindowCapture(_ image: NSImage?, on screen: NSScreen?) {
        guard onClose != nil else { return }
        guard let screen, let bitmap = ShotBitmap(capture: image) else { return captureFailed() }
        addWindow(for: screen, bitmap: bitmap, fixed: true)
        present()
    }

    @discardableResult
    private func addWindow(for screen: NSScreen, bitmap: ShotBitmap, fixed: Bool) -> QuickShotWindow {
        let window = QuickShotWindow(frame: screen.frame, visibleFrame: screen.visibleFrame, bitmap: bitmap,
                                     fixed: fixed, model: model, annotation: annotation,
                                     regionDisplay: .init(screen: screen, bitmap: bitmap), lastRegion: lastRegion)
        window.canvas.onCancel = { [weak self] in self?.cancel() }
        if !fixed { magnifier.track(window) }
        window.canvas.onSelect = { [weak self, weak window] in
            guard let self else { return }
            windows.filter { $0 !== window }.forEach { $0.canvas.clearSelection() }
            updateSelectionHints()
        }
        window.canvas.onDragStateChange = { [weak self] in self?.updateSelectionHints() }
        window.canvas.onSelectDisplay = { [weak self, weak window] in
            guard let window else { return }
            self?.selectEntireDisplay(in: window)
        }
        window.canvas.marksAnywhere = { [weak self] in
            self?.windows.contains { $0.canvas.hasMarks } ?? false
        }
        window.canvas.onOutput = { [weak self, weak window] action, crop in
            guard let self, let window, onClose != nil else { return }
            delivery.perform(action, crop: crop, in: window)
        }
        windows.append(window)
        return window
    }

    private var isWaitingForSelection: Bool { windows.allSatisfy { $0.canvas.isWaitingForSelection } }

    private func updateSelectionHints() {
        let visible = isWaitingForSelection
        windows.forEach { $0.canvas.hint?.isHidden = !visible }
    }

    private func selectEntireDisplay(in window: QuickShotWindow) {
        guard windows.contains(where: { $0 === window }), !windows.contains(where: \.canvas.hasMarks) else { return }
        window.canvas.select()
        if window.isVisible { focus(window) }
        windows.filter { $0 !== window }.forEach(dismiss)
        windows = [window]
    }

    private func present() {
        // Plonk stays inactive behind its panels, so an app switch is the signal that
        // still arrives while a Save As sheet, not a panel, holds the keyboard.
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        watchForAppSwitch()
        NotificationCenter.default.addObserver(
            self, selector: #selector(cancelOnAppSwitch), name: NSApplication.didResignActiveNotification,
            object: NSApp
        )
        updateSelectionHints()
        for window in windows {
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowResignedKey), name: NSWindow.didResignKeyNotification, object: window
            )
            window.show()
        }
        if let target = windowUnderPointer ?? windows.first { focus(target) }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleShortcut(event) == true ? nil : event
        }
        magnifier.start()
    }

    private var windowUnderPointer: QuickShotWindow? {
        let pointer = NSEvent.mouseLocation
        return windows.first { NSMouseInRect(pointer, $0.frame, false) }
    }

    private func focus(_ window: QuickShotWindow) {
        window.makeKey()
        window.makeFirstResponder(window.canvas)
    }

    private func handleShortcut(_ event: NSEvent) -> Bool {
        guard let window = windows.first(where: \.isKeyWindow), let command = window.shortcut(for: event) else {
            return false
        }
        switch command {
        case .selectDisplay:
            if NSEvent.pressedMouseButtons & 1 == 0, let target = windowUnderPointer {
                selectEntireDisplay(in: target)
                magnifier.update(at: NSEvent.mouseLocation)
            }
        case .restoreRegion:
            // Only from an empty start, as the hint offers it: never over a selection.
            guard isWaitingForSelection, NSEvent.pressedMouseButtons & 1 == 0,
                  let target = windows.first(where: { $0.restorableRegion != nil }) else { break }
            target.canvas.select(target.restorableRegion)
            focus(target)
            magnifier.update(at: NSEvent.mouseLocation)
        case .copyColor:
            // Copying ends the capture, so it must not throw away marks drawn on a selection.
            if let hex = magnifier.hex, !windows.contains(where: \.canvas.hasMarks) {
                NSPasteboard.general.replaceContents(with: hex)
                close(restoreFocus: true)
                HUD.shared.show(.hudCopied(hex))
            }
        case .zoomMagnifier(let increasing): magnifier.zoom(increasing: increasing)
        case .cancel:
            window.canvas.handle(command)
        default:
            guard !window.canvas.isTrackingPointer else { break }
            let target = windows.first { $0.canvas.hasSelection } ?? window
            target.canvas.handle(command)
        }
        return true
    }

    @objc private func windowResignedKey() {
        // Another display's panel or the Save As sheet can take focus during this event.
        DispatchQueue.main.async { [weak self] in
            guard let self, onClose != nil,
                  !windows.contains(where: { $0.isKeyWindow || $0.attachedSheet?.isKeyWindow == true })
            else { return }
            cancel()
        }
    }

    private func captureFailed() {
        cancel()
        HUD.shared.show(.shotCaptureFailed)
    }

    @objc private func cancel() {
        close(restoreFocus: true)
    }

    private var hasSwitchedApps: Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication, let previousApp else { return false }
        let pid = frontmost.processIdentifier
        return pid != previousApp.processIdentifier && pid != ProcessInfo.processInfo.processIdentifier
    }

    @objc private func frontmostAppChanged() {
        if hasSwitchedApps { cancelOnAppSwitch() }
    }

    @objc private func cancelOnAppSwitch() {
        close(restoreFocus: false)
    }

    private func dismiss(_ window: QuickShotWindow) {
        if let sheet = window.attachedSheet { window.endSheet(sheet, returnCode: .cancel) }
        window.orderOut(nil)
    }

    private func close(restoreFocus: Bool) {
        guard let onClose else { return }
        let shouldRestore = restoreFocus && NSApp.isActive
        self.onClose = nil
        captureTask?.cancel()
        captureTask = nil
        stopPicker()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        magnifier.stop()
        windows.forEach(dismiss)
        windows.removeAll()
        onClose()
        if shouldRestore, let previousApp,
           previousApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp.activate()
        }
    }
}
