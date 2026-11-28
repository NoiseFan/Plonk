import Foundation
import ScreenCaptureKit

extension SCShareableContent {
    func filterExcludingPlonk(on display: SCDisplay) -> SCContentFilter {
        SCContentFilter(display: display, excludingApplications: applications.filter {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }, exceptingWindows: [])
    }

    /// A still of the display without Plonk's windows, except its menu bar item,
    /// which belongs in a picture of the menu bar like every other app's. A live
    /// stream wants `filterExcludingPlonk`, which also covers windows opened later.
    func screenshotFilter(on display: SCDisplay) -> SCContentFilter {
        let own = ProcessInfo.processInfo.processIdentifier
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))
        return SCContentFilter(display: display, excludingWindows: windows.filter {
            $0.owningApplication?.processID == own && $0.windowLayer != statusLayer
        })
    }
}
