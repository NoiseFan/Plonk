import AppKit
import ImageIO
import UniformTypeIdentifiers

final class ShotArtifacts {
    private let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("plonk-e2e-results-\(UUID().uuidString)", isDirectory: true)
    private let environment: [String]
    private var steps: [String] = []
    private var started = Date()
    private var exportedImage: CGImage?
    var failureScreen: CGImage?

    init() {
        let revision = ProcessInfo.processInfo.environment["PLONK_E2E_REVISION"] ?? "unknown"
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        environment = ["Revision: \(revision)", "macOS: \(os)"] + NSScreen.screens.map { screen in
            "Display: \(screen.localizedName), frame \(screen.frame), scale \(screen.backingScaleFactor)"
        }
    }

    func begin() {
        steps.removeAll(keepingCapacity: true)
        started = Date()
        exportedImage = nil
        failureScreen = nil
    }

    func note(_ step: String) {
        steps.append(String(format: "%7.3fs %@", Date().timeIntervalSince(started), step))
    }

    func recordExport(_ image: CGImage) {
        note("Decoded image \(image.width) × \(image.height) pixels")
        exportedImage = image
    }

    func writeFailure(id: String, status: String, details: String) throws -> URL {
        let directory = root.appendingPathComponent(id, isDirectory: true)
        let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o700]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: attributes)
        let summary = environment + ["Case: \(id)", "Status: \(status)", details, ""] + steps
        try (summary.joined(separator: "\n") + "\n")
            .write(to: directory.appendingPathComponent("trace.txt"), atomically: true, encoding: .utf8)
        if let exportedImage {
            try writePNG(exportedImage, to: directory.appendingPathComponent("export.png"))
        }
        if let failureScreen {
            try writePNG(failureScreen, to: directory.appendingPathComponent("display.png"))
        }
        return directory
    }

    private func writePNG(_ image: CGImage, to path: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(path as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw E2EFailure("Could not create \(path.lastPathComponent).") }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw E2EFailure("Could not write \(path.lastPathComponent).")
        }
    }
}
