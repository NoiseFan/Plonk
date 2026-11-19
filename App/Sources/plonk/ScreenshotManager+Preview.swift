import AppKit

extension ScreenshotManager {
    static func cleanPreviewFiles() {
        let directory = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            for file in files where file.lastPathComponent.hasPrefix("plonk-preview-") && file.pathExtension == "png" {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    static func openInPreview(_ image: NSImage, completion: @escaping (Bool) -> Void) {
        let workspace = NSWorkspace.shared
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("plonk-preview-\(UUID().uuidString).png")
        guard let preview = workspace.urlForApplication(withBundleIdentifier: "com.apple.Preview"),
              save(image, to: .path(url.path)) != nil else {
            completion(false)
            return
        }
        workspace.open([url], withApplicationAt: preview, configuration: .init()) { _, error in
            DispatchQueue.main.async { completion(error == nil) }
            if error != nil {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }
}
