import AppKit
import ApplicationServices
import Carbon.HIToolbox
import ImageIO

struct ShotOutputCases {
    let desktop: Desktop

    func saveAs(cancel: Bool) throws {
        let files = FileManager.default
        let directory = files.temporaryDirectory.appendingPathComponent("plonk-e2e-\(UUID().uuidString)")
        try files.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: directory) }

        try desktop.press("Save As")
        _ = try desktop.wait("save sheet") { desktop.hasSheet() ? true : nil }
        let nameField = desktop.focusedTextField()
        try desktop.key(kVK_ANSI_G, flags: [.maskCommand, .maskShift])
        _ = try desktop.wait("Go to Folder field") {
            guard let current = desktop.focusedTextField() else { return nil as AXUIElement? }
            if let nameField, CFEqual(nameField, current) { return nil }
            return current
        }
        try desktop.paste(directory.path)
        try desktop.key(kVK_Return)
        _ = try desktop.wait("destination folder") { desktop.element(directory.lastPathComponent) }
        if cancel {
            try desktop.key(kVK_Escape)
            _ = try desktop.wait("save sheet to close") { desktop.hasSheet() ? nil : true }
            guard try files.contentsOfDirectory(atPath: directory.path).isEmpty else {
                throw E2EFailure("Cancel created a screenshot file.")
            }
        } else {
            try desktop.press("Save")
            let image = try desktop.wait("PNG in chosen folder") {
                let outputs = try? files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                return outputs?.lazy.compactMap(loadOutputPNG).first
            }
            desktop.artifacts.recordExport(image)
        }
    }
}

extension ShotCases {
    func previewOutput() throws {
        try desktop.key(kVK_ANSI_0)
        try mark(from: CGPoint(x: 130, y: 75), to: CGPoint(x: 225, y: 150))
        let bundleID = "com.apple.Preview"
        let originalWindows = previewDocuments(bundleID: bundleID).map(\.0)
        try desktop.press("Open in Preview")
        let (document, url) = try desktop.wait("new document in Preview") {
            previewDocuments(bundleID: bundleID).first { candidate in
                !originalWindows.contains(where: { CFEqual($0, candidate.0) })
            }
        }
        defer {
            if let button = desktop.attribute(document, kAXCloseButtonAttribute),
               CFGetTypeID(button) == AXUIElementGetTypeID() {
                AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
            }
            try? FileManager.default.removeItem(at: url)
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw E2EFailure("Preview document cannot be decoded.")
        }
        desktop.artifacts.recordExport(image)
        let center = try sample(image, at: CGPoint(x: 180, y: 115))
        try require(center[0] < 12 && center[1] < 12 && center[2] < 12,
                    "Expected the annotated region in the Preview document.")
    }

    private func previewDocuments(bundleID: String) -> [(AXUIElement, URL)] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).flatMap { process in
            let application = AXUIElementCreateApplication(process.processIdentifier)
            let windows = desktop.attribute(application, kAXWindowsAttribute) as? [AXUIElement] ?? []
            return windows.compactMap { window -> (AXUIElement, URL)? in
                guard let value = desktop.attribute(window, kAXDocumentAttribute) as? String,
                      let url = URL(string: value), url.isFileURL,
                      url.lastPathComponent.hasPrefix("plonk-preview-") else { return nil }
                return (window, url)
            }
        }
    }
}

extension ShotCases {
    func defaultOutput() throws {
        let files = FileManager.default
        let directory = files.temporaryDirectory.appendingPathComponent("plonk-default-e2e-\(UUID().uuidString)")
        try files.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? files.removeItem(at: directory) }

        try openCaptureSettings()
        let field = try desktop.wait("Save folder field") {
            desktop.element("Save folder", role: kAXTextFieldRole)
        }
        guard let previous = desktop.attribute(field, kAXValueAttribute) as? String, !previous.isEmpty else {
            throw E2EFailure("Cannot read the existing screenshot directory.")
        }
        var needsRestore = true
        defer { if needsRestore { try? setDefaultFolder(previous) } }
        try setDefaultFolder(directory.path)
        let baseline = desktop.windowCount()
        desktop.activateFixture()
        defer { desktop.dismissCapture(above: baseline) }
        try selectRegion()
        try desktop.press("Save to Folder")
        let image = try desktop.wait("PNG in the configured directory") {
            let contents = try? files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            return contents?.lazy.compactMap(loadOutputPNG).first
        }
        desktop.artifacts.recordExport(image)
        try setDefaultFolder(previous)
        needsRestore = false
    }

    private func setDefaultFolder(_ path: String) throws {
        try openCaptureSettings()
        let field = try desktop.wait("Save folder field") {
            desktop.element("Save folder", role: kAXTextFieldRole)
        }
        try desktop.click(desktop.center(of: field))
        try desktop.key(kVK_ANSI_A, flags: .maskCommand)
        try desktop.paste(path)
        try desktop.key(kVK_Return)
        let config = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Plonk/config.json")
        _ = try desktop.wait("configured screenshot directory") {
            guard let data = try? Data(contentsOf: config),
                  let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  payload["shotFolder"] as? String == path else { return nil as Bool? }
            return true
        }
    }
}


private func loadOutputPNG(_ url: URL) -> CGImage? {
    guard url.pathExtension == "png", let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}
