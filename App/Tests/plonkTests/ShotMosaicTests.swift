import AppKit
import Testing
@testable import plonk

struct ShotMosaicTests {
    @MainActor
    @Test func mosaicPatchAndRedactionStayAlignedAfterHandoff() throws {
        let context = try #require(CGContext(
            data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        let bitmap = ShotBitmap(image: try #require(context.makeImage()))
        let points = [CGPoint(x: 0.125, y: 0.125), CGPoint(x: 0.625, y: 0.375)]
        let mosaic = Annotation(kind: .mosaic, points: points, colorIndex: 0, width: 0.01, mosaicBlockSize: 12)
        let rendered = try #require(ShotMosaic.render(mosaic, from: bitmap))
        let patch = try #require(rendered.mosaicPatch)
        #expect(patch.width == 32 && patch.height == 16)

        let redact = Annotation(kind: .redact, points: points, colorIndex: 0, width: 0.01)
        let opaque = try #require(ShotMosaic.render(redact, from: bitmap))
        let crop = CGRect(x: 0.25, y: 0, width: 0.5, height: 1)
        let rebased = rendered.rebased(to: crop)
        #expect(rebased.mosaicBlockSize == 12)
        #expect(rebased.mosaicPatch === patch)
        let position = rebased.boundingRect(in: CGSize(width: 32, height: 64))
        #expect(position == CGRect(x: -8, y: 8, width: 32, height: 16))

        let source = try #require(bitmap.crop(CGRect(x: 16, y: 0, width: 32, height: 64)))
        let output = try #require(source.annotated(with: [rebased, opaque.rebased(to: crop)]))
        let data = try #require(ScreenshotManager.pngData(from: output))
        let png = try #require(NSBitmapImageRep(data: data))
        let covered = try #require(png.colorAt(x: 0, y: 16)?.usingColorSpace(.deviceRGB))
        let untouched = try #require(png.colorAt(x: 31, y: 16)?.usingColorSpace(.deviceRGB))
        #expect(covered.redComponent < 0.01 && covered.alphaComponent > 0.99)
        #expect(untouched.redComponent > 0.99 && untouched.greenComponent > 0.99)
    }
}
