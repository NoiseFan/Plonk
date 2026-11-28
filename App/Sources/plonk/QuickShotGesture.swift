import CoreGraphics

enum QuickShotGesture {
    case create(ShotRegionGesture)
    case adjust(from: CGPoint, original: CGRect, handle: CGPoint)
    case mark

    var isDraggingRegionBoundary: Bool {
        switch self {
        case .create: return true
        case .adjust(_, _, let handle): return handle != .zero
        case .mark: return false
        }
    }

    var drawingRegion: ShotRegionGesture? {
        guard case .create(let region) = self, region.isDragging else { return nil }
        return region
    }
}
