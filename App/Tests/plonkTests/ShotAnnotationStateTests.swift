import CoreGraphics
import Testing
@testable import plonk

struct ShotAnnotationStateTests {
    @Test func captureStartsWithAllConfiguredStyles() {
        let defaults = AnnotationStyles(rectangle: .init(width: 5, color: .green),
                                       ellipse: .init(width: 8, color: .blue),
                                       arrow: .init(width: 12, color: .purple),
                                       highlight: .init(width: 31, color: .orange),
                                       pen: .init(width: 42, color: .black))

        let capture = ShotAnnotationState(defaults: defaults)

        #expect(capture.styles == defaults)
    }

    @Test func toolSwitchingRecallsEachToolsTemporaryStyle() throws {
        let capture = ShotAnnotationState(defaults: .init())
        capture.tool = .rectangle
        capture.styles.rectangle = .init(width: 5, color: .green)
        capture.tool = .ellipse
        capture.styles.ellipse = .init(width: 8, color: .blue)
        capture.tool = .rectangle

        var history = AnnotationHistory()
        capture.beginMark(in: &history, at: .zero, viewWidth: 1000)

        let mark = try #require(history.live)
        #expect(mark.colorIndex == AnnotationColor.green.index)
        #expect(mark.width == 0.005)
    }

    @Test func lineStylesStayIndependentAcrossToolsAndCaptures() throws {
        let defaults = AnnotationStyles(line: .init(width: 8, color: .blue),
                                        arrow: .init(width: 12, color: .purple))
        let capture = ShotAnnotationState(defaults: defaults)
        capture.tool = .line
        capture.styles.line = .init(width: 5, color: .green)
        capture.enterEditor()
        #expect(capture.tool == .line)

        var history = AnnotationHistory()
        for kind in [Annotation.Kind.line, .arrow, .line] {
            capture.tool = kind
            capture.beginMark(in: &history, at: .zero, viewWidth: 500)
            history.end(at: CGPoint(x: 0.5, y: 0.5))
        }
        #expect(history.annotations.map(\.colorIndex) == [AnnotationColor.green.index, AnnotationColor.purple.index,
                                                        AnnotationColor.green.index])
        #expect(history.annotations.map { $0.width * 500 } == [5, 12, 5])

        let next = ShotAnnotationState(defaults: defaults)
        next.enterEditor()
        next.tool = .line
        next.beginMark(in: &history, at: .zero, viewWidth: 500)
        let mark = try #require(history.live)
        #expect(mark.colorIndex == AnnotationColor.blue.index)
        #expect(mark.width * 500 == 8)
    }

    @Test func openingEditorKeepsSelectedToolBeforeAnyMarksExist() {
        let capture = ShotAnnotationState(defaults: .init())
        capture.tool = .rectangle

        capture.enterEditor()

        #expect(capture.tool == .rectangle)
    }

    @Test func openingEditorFromMoveModeSelectsArrow() {
        let capture = ShotAnnotationState(defaults: .init())

        capture.enterEditor()

        #expect(capture.tool == .arrow)
    }

    @Test func firstEditorMarkUsesTheTemporaryStyle() throws {
        let capture = ShotAnnotationState(defaults: .init())
        capture.tool = .rectangle
        capture.styles.rectangle = .init(width: 5, color: .green)

        capture.enterEditor()
        var history = AnnotationHistory()
        capture.beginMark(in: &history, at: .zero, viewWidth: 500)

        let mark = try #require(history.live)
        #expect(mark.colorIndex == AnnotationColor.green.index)
        #expect(mark.width * 500 == 5)
    }
}
