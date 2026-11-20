import AppKit
import Testing
@testable import plonk

struct QuickShotRecognitionTests {
    @MainActor
    @Test func repeatedRecognitionWaitsForCurrentRequest() throws {
        let canvas = try makeCanvas()
        let token = try #require(canvas.beginRecognition())

        #expect(canvas.beginRecognition() == nil)

        canvas.finishRecognition(.failure(CocoaError(.fileReadUnknown)), token: token)
        #expect(canvas.beginRecognition() != nil)
    }

    @MainActor
    @Test func staleCompletionDoesNotUnlockNewRequest() throws {
        let canvas = try makeCanvas()
        let oldToken = try #require(canvas.beginRecognition())
        #expect(canvas.dismissRecognition())
        let currentToken = try #require(canvas.beginRecognition())

        canvas.finishRecognition(.failure(CocoaError(.fileReadUnknown)), token: oldToken)
        #expect(canvas.beginRecognition() == nil)

        canvas.finishRecognition(.failure(CocoaError(.fileReadUnknown)), token: currentToken)
        #expect(canvas.beginRecognition() != nil)
    }

    @MainActor
    private func makeCanvas() throws -> QuickShotCanvas {
        _ = NSApplication.shared
        let context = try #require(CGContext(
            data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = NSImage(bitmap: try #require(context.makeImage()))
        let bitmap = try #require(ShotBitmap(image))
        let frame = CGRect(origin: .zero, size: bitmap.size)
        return QuickShotCanvas(bitmap: bitmap, frame: frame, safeArea: frame)
    }
}
