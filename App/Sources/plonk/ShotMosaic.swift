import CoreImage.CIFilterBuiltins

enum ShotMosaic {
    private static let context = CIContext()

    static func render(_ mark: Annotation, from bitmap: ShotBitmap) -> Annotation? {
        let bounds = CGRect(origin: .zero, size: bitmap.size)
        let rect = mark.boundingRect(in: bitmap.size)
        guard !rect.isEmpty else { return nil }
        let pixels = rect.integral.intersection(bounds)
        guard !pixels.isEmpty else { return nil }

        var result = mark
        result.points = [
            ImageFit.unitPoint(pixels.origin, in: bounds),
            ImageFit.unitPoint(CGPoint(x: pixels.maxX, y: pixels.maxY), in: bounds),
        ]
        if mark.kind == .redact { return result }

        guard let blockSize = mark.mosaicBlockSize else { return nil }
        let input = CIImage(cgImage: bitmap.image)
        let filter = CIFilter.pixellate()
        filter.inputImage = input.clampedToExtent()
        filter.scale = Float(blockSize)
        // Core Image uses a bottom-left origin. Anchor the grid to the source
        // pixels so changing the mark or the screenshot crop cannot shift it.
        let halfBlock = CGFloat(blockSize) / 2
        filter.center = CGPoint(x: halfBlock, y: bounds.maxY - halfBlock)
        let extent = CGRect(x: pixels.minX, y: bounds.maxY - pixels.maxY,
                            width: pixels.width, height: pixels.height)
        guard let output = filter.outputImage,
              let patch = context.createCGImage(output, from: extent) else { return nil }
        result.mosaicPatch = patch
        return result
    }
}
