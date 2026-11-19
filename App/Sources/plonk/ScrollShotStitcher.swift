import CoreGraphics
import Vision

struct ScrollShotStitcher {
    enum Update: Equatable { case accepted, unchanged, rejected, full }

    private var previous: CGImage?
    private var strips: [CGImage] = []
    private var height = 0

    mutating func append(_ frame: CGImage) -> Update {
        guard let previous else {
            previous = frame
            strips = [frame]
            height = frame.height
            return .accepted
        }
        guard frame.width == previous.width, frame.height == previous.height else { return .rejected }
        guard let old = Self.samples(previous), let new = Self.samples(frame) else { return .rejected }
        if Self.matches(old, new, shift: 0) { return .unchanged }

        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: frame)
        let handler = VNImageRequestHandler(cgImage: previous)
        guard (try? handler.perform([request])) != nil, let transform = request.results?.first?.alignmentTransform,
              transform.tx.isFinite, abs(transform.tx) <= 1,
              transform.ty.isFinite, abs(transform.ty) < CGFloat(frame.height) else { return .rejected }

        let displacement = Int(abs(transform.ty).rounded())
        guard let strip = Self.newStrip(frame, displacement: displacement, old: old, new: new) else {
            return .rejected
        }
        guard height + strip.height <= 24_000, (height + strip.height) * frame.width <= 40_000_000 else {
            return .full
        }
        // A cropped CGImage can retain its whole source frame.
        guard let storage = Self.canvas(width: strip.width, height: strip.height) else { return .full }
        storage.draw(strip, in: CGRect(x: 0, y: 0, width: strip.width, height: strip.height))
        guard let compact = storage.makeImage() else { return .full }
        strips.append(compact)
        self.previous = frame
        height += strip.height
        return .accepted
    }

    private static func newStrip(_ frame: CGImage, displacement: Int, old: [UInt8], new: [UInt8]) -> CGImage? {
        guard displacement > 0, displacement <= frame.height * 3 / 4,
              matches(old, new, shift: displacement),
              !matches(new, old, shift: displacement) else { return nil }
        return frame.cropping(to: CGRect(x: 0, y: frame.height - displacement,
                                         width: frame.width, height: displacement))
    }

    // Keep every scanline for pixel-accurate vertical comparison while sampling across the width.
    private static let sampleWidth = 48

    private static func samples(_ image: CGImage) -> [UInt8]? {
        var bytes = [UInt8](repeating: 0, count: sampleWidth * image.height)
        let drawn = bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: sampleWidth, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: sampleWidth,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: 0) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: sampleWidth, height: image.height))
            return true
        }
        return drawn ? bytes : nil
    }

    private static func matches(_ old: [UInt8], _ new: [UInt8], shift: Int) -> Bool {
        let offset = shift * sampleWidth
        let count = old.count - offset
        var error = 0
        var changed = 0
        for index in 0..<count {
            let distance = abs(Int(old[index + offset]) - Int(new[index]))
            error += distance
            if distance > 20 { changed += 1 }
        }
        return error <= count * 4 && changed <= count / 20
    }

    func image(fitting limit: CGSize? = nil) -> CGImage? {
        guard let first = strips.first else { return nil }
        let scale = limit.map { min(1, $0.width / CGFloat(first.width), $0.height / CGFloat(height)) } ?? 1
        let width = max(1, Int((CGFloat(first.width) * scale).rounded()))
        let outputHeight = max(1, Int((CGFloat(height) * scale).rounded()))
        guard let context = Self.canvas(width: width, height: outputHeight) else { return nil }
        var top = 0
        for strip in strips {
            let next = top + strip.height
            let upper = Int((CGFloat(top) * scale).rounded())
            let lower = Int((CGFloat(next) * scale).rounded())
            context.draw(strip, in: CGRect(x: 0, y: outputHeight - lower, width: width, height: lower - upper))
            top = next
        }
        return context.makeImage()
    }

    private static func canvas(width: Int, height: Int) -> CGContext? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                         bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
    }
}
