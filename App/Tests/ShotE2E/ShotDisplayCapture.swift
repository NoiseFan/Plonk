import AppKit
import ScreenCaptureKit

extension ShotCases {
    func recordFailureScreen() {
        guard #available(macOS 14.0, *), CGPreflightScreenCaptureAccess() else { return }
        do { desktop.artifacts.failureScreen = try captureFixtureRegion(wholeDisplay: true) }
        catch { desktop.artifacts.note("Display capture unavailable: \(error)") }
    }

    @available(macOS 14.0, *)
    func captureFixtureRegion(wholeDisplay: Bool = false) throws -> CGImage {
        guard let screen = desktop.fixture.screen,
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            throw E2EFailure("Cannot determine the recognition fixture's display.")
        }
        let id = displayID.uint32Value
        let scale = screen.backingScaleFactor
        let displayBounds = CGDisplayBounds(id)
        let region = wholeDisplay ? CGRect(origin: .zero, size: displayBounds.size)
            : desktop.region.offsetBy(dx: -displayBounds.minX, dy: -displayBounds.minY)
        var result: Result<CGImage, Error>?
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.displayID == id }) else {
                    throw E2EFailure("Recognition fixture display disappeared.")
                }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.sourceRect = region
                config.width = Int(region.width * scale)
                config.height = Int(region.height * scale)
                config.showsCursor = false
                result = .success(try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config))
            } catch {
                result = .failure(error)
            }
        }
        return try desktop.wait("display screenshot", timeout: 8) { result }.get()
    }
}
