import ApplicationServices

extension Desktop {
    func matchingElements(_ label: String) -> Int {
        let app = AXUIElementCreateApplication(plonk.processIdentifier)
        let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
        return windows.reduce(0) { $0 + count(label, under: $1, depth: 0) }
    }

    private func count(_ label: String, under element: AXUIElement, depth: Int) -> Int {
        guard depth < 16 else { return 0 }
        let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
        return children.reduce(matches(label, on: element) ? 1 : 0) {
            $0 + count(label, under: $1, depth: depth + 1)
        }
    }

    func find(_ label: String, role: String?, under element: AXUIElement, depth: Int) -> AXUIElement? {
        guard depth < 16 else { return nil }
        if matches(label, on: element),
           role == nil || attribute(element, kAXRoleAttribute) as? String == role { return element }
        let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
        return children.lazy.compactMap { self.find(label, role: role, under: $0, depth: depth + 1) }.first
    }

    private func matches(_ label: String, on element: AXUIElement) -> Bool {
        [kAXIdentifierAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute, kAXValueAttribute, kAXPlaceholderValueAttribute]
            .contains { attribute(element, $0) as? String == label }
    }
}
