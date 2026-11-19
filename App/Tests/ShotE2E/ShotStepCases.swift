import AppKit
import Carbon.HIToolbox
import Vision

extension ShotCases {
    func stepNumbers() throws {
        let first = CGPoint(x: 115, y: 110)
        let second = CGPoint(x: 210, y: 110)
        try desktop.key(kVK_ANSI_8)
        try desktop.click(global(first))
        try desktop.click(global(second))
        let image = try copySelection()
        try require(try stepDigit(image, at: first) == "1", "First marker did not show 1.")
        try require(try stepDigit(image, at: second) == "2", "Second marker did not show 2.")
    }

    func stepDigit(_ image: CGImage, at point: CGPoint) throws -> String? {
        let scale = CGFloat(image.width) / desktop.region.width
        let rect = CGRect(x: (point.x - 6) * scale, y: (point.y - 8) * scale,
                          width: 12 * scale, height: 16 * scale).integral
        guard let glyph = image.cropping(to: rect),
              let input = CGContext(data: nil, width: 120, height: 120, bitsPerComponent: 8,
                                    bytesPerRow: 0, space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            throw E2EFailure("Cannot prepare the step marker glyph.")
        }
        input.setFillColor(gray: 0, alpha: 1)
        input.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
        input.interpolationQuality = .none
        input.draw(glyph, in: CGRect(x: 30, y: 20, width: 60, height: 80))
        guard let magnified = input.makeImage() else { throw E2EFailure("Cannot magnify step marker glyph.") }
        let request = VNRecognizeTextRequest()
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: magnified).perform([request])
        return request.results?.first?.topCandidates(1).first?.string
    }
}
