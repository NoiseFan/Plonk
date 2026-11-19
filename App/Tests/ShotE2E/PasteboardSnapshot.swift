import AppKit

struct PasteboardSnapshot {
    private let pasteboard: NSPasteboard
    private let changeCount: Int
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        changeCount = pasteboard.changeCount
        items = (pasteboard.pasteboardItems ?? []).map { item in
            var contents: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { contents[type] = item.data(forType: type) }
            return contents
        }
    }

    func restore() {
        guard pasteboard.changeCount != changeCount else { return }
        let restored = items.map { contents in
            let item = NSPasteboardItem()
            for (type, data) in contents { item.setData(data, forType: type) }
            return item
        }
        pasteboard.clearContents()
        if !restored.isEmpty { pasteboard.writeObjects(restored) }
    }
}
