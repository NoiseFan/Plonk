import AppKit

extension ShotCases {
    func pixel(_ image: CGImage, x: Int, y: Int) throws -> [UInt8] {
        guard let patch = image.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw E2EFailure("Cannot crop pixel.")
        }
        var bytes = [UInt8](repeating: 0, count: 4)
        try bytes.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                          bytesPerRow: 4, space: colorSpace,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw E2EFailure("Cannot create pixel context.")
            }
            context.draw(patch, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return bytes
    }
}
