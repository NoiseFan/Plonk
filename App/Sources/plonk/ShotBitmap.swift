import AppKit

struct ShotBitmap {
    let image: CGImage
    var size: CGSize { CGSize(width: image.width, height: image.height) }
    let scale: CGFloat

    init(image: CGImage, scale: CGFloat = 1) {
        self.image = image
        self.scale = scale
    }

    init?(_ source: NSImage) {
        guard source.size.width > 0,
              let image = source.representations.compactMap({ $0 as? NSBitmapImageRep })
            .max(by: { $0.pixelsWide < $1.pixelsWide })?.cgImage else { return nil }
        self.image = image
        scale = CGFloat(image.width) / source.size.width
    }

    func crop(_ rect: CGRect) -> NSImage? {
        guard let crop = image.cropping(to: rect) else { return nil }
        return NSImage(bitmap: crop, logicalSize: CGSize(width: rect.width / scale, height: rect.height / scale))
    }
}

extension NSImage {
    convenience init(bitmap: CGImage, logicalSize: CGSize? = nil) {
        let representation = NSBitmapImageRep(cgImage: bitmap)
        if let logicalSize { representation.size = logicalSize }
        self.init(size: representation.size)
        addRepresentation(representation)
    }
}
