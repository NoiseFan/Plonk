import AppKit
import ScreenCaptureKit

final class ScrollShotCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    enum Status { case ready, paused, full, failed }
    private let queue = DispatchQueue(label: "dev.plonk.scroll-shot")
    private let context = CIContext()
    private var stitcher = ScrollShotStitcher()
    private var stream: SCStream?
    private var starting: Task<Void, Never>?
    private var stopped = false
    private var full = false
    private var paused = false
    let onUpdate: (CGImage?, Status) -> Void

    init(onUpdate: @escaping (CGImage?, Status) -> Void) {
        self.onUpdate = onUpdate
    }

    @MainActor
    func start(displayID: CGDirectDisplayID, region: CGRect, pixels: CGSize) {
        starting = Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard !Task.isCancelled else { return }
                guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                    onUpdate(nil, .failed)
                    return
                }
                let filter = SCContentFilter(display: display, excludingApplications: content.applications.filter {
                    $0.processID == ProcessInfo.processInfo.processIdentifier
                }, exceptingWindows: [])
                let configuration = SCStreamConfiguration()
                configuration.sourceRect = region
                configuration.width = Int(pixels.width)
                configuration.height = Int(pixels.height)
                configuration.showsCursor = false
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 12)
                configuration.pixelFormat = kCVPixelFormatType_32BGRA
                let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
                try await stream.startCapture()
                if Task.isCancelled {
                    try? await stream.stopCapture()
                } else {
                    self.stream = stream
                }
            } catch {
                if !Task.isCancelled { onUpdate(nil, .failed) }
            }
        }
    }

    func stop(result: ((CGImage?) -> Void)? = nil) {
        starting?.cancel()
        starting = nil
        if let stream { Task { try? await stream.stopCapture() } }
        stream = nil
        queue.async {
            self.stopped = true
            if let result {
                let image = self.stitcher.image()
                DispatchQueue.main.async { result(image) }
            }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { self.onUpdate(nil, .failed) }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard !stopped, !full, type == .screen, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int, status == SCFrameStatus.complete.rawValue,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let source = CIImage(cvImageBuffer: pixels)
        guard let frame = context.createCGImage(source, from: source.extent) else { return }
        let update = stitcher.append(frame)
        switch update {
        case .accepted:
            paused = false
            let preview = stitcher.image(fitting: CGSize(width: 190, height: 360))
            DispatchQueue.main.async { self.onUpdate(preview, .ready) }
        case .unchanged:
            if paused {
                paused = false
                DispatchQueue.main.async { self.onUpdate(nil, .ready) }
            }
        case .rejected:
            if !paused {
                paused = true
                DispatchQueue.main.async { self.onUpdate(nil, .paused) }
            }
        case .full:
            full = true
            DispatchQueue.main.async { self.onUpdate(nil, .full) }
        }
    }
}
