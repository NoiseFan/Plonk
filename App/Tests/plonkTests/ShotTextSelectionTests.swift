import CoreGraphics
import Testing
@testable import plonk

struct ShotTextSelectionTests {
    @Test func dragUsesRecognizedPositionsAndCopiesOnlyTheSelectedCharacters() throws {
        let first = TextExtractor.Line(
            text: "你好！", box: FracRect(0, 0.2, 0.6, 0.05), confidence: 1,
            characterBoxes: [FracRect(0, 0.2, 0.1, 0.05), FracRect(0.1, 0.2, 0.4, 0.05), FracRect(0.5, 0.2, 0.1, 0.05)]
        )
        let second = TextExtractor.Line(text: "Next", box: FracRect(0, 0.4, 0.4, 0.05), confidence: 1)
        var selection = ShotTextSelection(lines: [second, first])
        let start = try #require(selection.nearest(to: CGPoint(x: 0.15, y: 0.22)))
        let end = try #require(selection.nearest(to: CGPoint(x: 0.05, y: 0.42)))
        selection.select(start, extending: false)
        selection.select(end, extending: true)
        #expect(selection.text == "好！\nN")
    }

    @Test func keyboardCanExtendAndSelectAll() {
        let line = TextExtractor.Line(text: "abcdef", box: FracRect(0, 0, 1, 0.2), confidence: 1)
        var selection = ShotTextSelection(lines: [line])
        selection.move(by: -1, extending: false)
        selection.move(by: -1, extending: true)
        #expect(selection.text == "ef")
        selection.selectAll()
        #expect(selection.text == line.text)
    }

    @Test func charactersSharingAWordBoxCanBeSelectedIndividually() throws {
        let word = FracRect(0.2, 0.1, 0.4, 0.1)
        let line = TextExtractor.Line(text: "WORD", box: word, confidence: 1,
                                      characterBoxes: Array(repeating: word, count: 4))
        var selection = ShotTextSelection(lines: [line])
        let index = try #require(selection.nearest(to: CGPoint(x: 0.45, y: 0.15)))
        selection.select(index, extending: false)
        #expect(selection.text == "R")
    }
}
