import CoreGraphics
import Foundation
import Testing
@testable import plonk

struct ScrollShotStitcherTests {
    @Test func appendsOnlyNewRowsAfterVerifiedOverlap() throws {
        let page = try pageImage()
        let first = try #require(page.cropping(to: CGRect(x: 0, y: 0, width: 128, height: 128)))
        let next = try #require(page.cropping(to: CGRect(x: 0, y: 36, width: 128, height: 128)))
        var stitcher = ScrollShotStitcher()
        #expect(stitcher.append(first) == .accepted)
        #expect(stitcher.append(first) == .unchanged)
        #expect(stitcher.append(next) == .accepted)
        #expect(stitcher.append(first) == .rejected)
        #expect(stitcher.image()?.height == 164)
        #expect(stitcher.image()?.width == 128)
    }

    @Test func keepsAcceptedFrameWhenOverlapIsTooSmall() throws {
        let page = try pageImage()
        let first = try #require(page.cropping(to: CGRect(x: 0, y: 0, width: 128, height: 128)))
        let far = try #require(page.cropping(to: CGRect(x: 0, y: 112, width: 128, height: 128)))
        let near = try #require(page.cropping(to: CGRect(x: 0, y: 36, width: 128, height: 128)))
        var stitcher = ScrollShotStitcher()
        #expect(stitcher.append(first) == .accepted)
        #expect(stitcher.append(far) == .rejected)
        #expect(stitcher.image()?.height == 128)
        #expect(stitcher.append(near) == .accepted)
    }

    private func pageImage() throws -> CGImage {
        let width = 128
        let height = 240
        let bytes = (0..<(width * height)).map { index -> UInt8 in
            let x = index % width / 4
            let y = index / width / 4
            return UInt8(truncatingIfNeeded: (x * 739 ^ y * 11311 ^ x * y * 107) >> 3)
        }
        let provider = try #require(CGDataProvider(data: Data(bytes) as CFData))
        return try #require(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
                                    bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: [], provider: provider, decode: nil,
                                    shouldInterpolate: false, intent: .defaultIntent))
    }
}
