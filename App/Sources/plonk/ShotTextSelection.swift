import CoreGraphics

struct ShotTextSelection {
    struct Glyph {
        let character: Character
        let box: CGRect?
    }

    let glyphs: [Glyph]
    private var anchor: Int?
    private var end: Int?

    init(lines: [TextExtractor.Line]) {
        var glyphs: [Glyph] = []
        for line in TextExtractor.readingOrder(lines) where !line.text.isEmpty {
            if !glyphs.isEmpty { glyphs.append(Glyph(character: "\n", box: nil)) }
            glyphs.append(contentsOf: Self.glyphs(in: line))
        }
        self.glyphs = glyphs
    }

    private static func glyphs(in line: TextExtractor.Line) -> [Glyph] {
        let characters = Array(line.text)
        let boxes = line.characterBoxes.count == characters.count
            ? line.characterBoxes : Array(repeating: nil, count: characters.count)
        let fallbackWidth = line.box.w / Double(characters.count)
        var result: [Glyph] = []
        var start = 0
        while start < characters.count {
            let box = boxes[start]
            var end = start + 1
            // Vision can return the same word bounds for every letter.
            if box != nil {
                while end < characters.count, boxes[end] == box { end += 1 }
            }
            let bounds = box ?? FracRect(line.box.x + Double(start) * fallbackWidth,
                                         line.box.y, fallbackWidth, line.box.h)
            let width = bounds.w / Double(end - start)
            for index in start..<end {
                let rect = CGRect(x: bounds.x + Double(index - start) * width, y: bounds.y,
                                  width: width, height: bounds.h)
                result.append(Glyph(character: characters[index], box: rect))
            }
            start = end
        }
        return result
    }

    var selected: ArraySlice<Glyph> {
        guard let anchor, let end else { return [] }
        return glyphs[min(anchor, end)...max(anchor, end)]
    }

    var text: String { String(selected.map(\.character)) }

    func nearest(to point: CGPoint) -> Int? {
        func distance(_ rect: CGRect) -> Double {
            let dx = max(rect.minX - point.x, point.x - rect.maxX, 0)
            let dy = max(rect.minY - point.y, point.y - rect.maxY, 0)
            return dy * 4 + dx
        }
        return glyphs.indices.compactMap { index in
            glyphs[index].box.map { (index, distance($0)) }
        }.min { $0.1 < $1.1 }?.0
    }

    mutating func select(_ index: Int, extending: Bool) {
        guard glyphs.indices.contains(index) else { return }
        if !extending || anchor == nil { anchor = index }
        end = index
    }

    mutating func move(by offset: Int, extending: Bool) {
        guard !glyphs.isEmpty else { return }
        let next = ((end ?? (offset > 0 ? -1 : glyphs.count)) + offset).clamped(to: 0...(glyphs.count - 1))
        select(next, extending: extending)
    }

    mutating func selectAll() {
        guard !glyphs.isEmpty else { return }
        anchor = 0
        end = glyphs.count - 1
    }
}
