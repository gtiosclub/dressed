import XCTest
@testable import dressed

@MainActor
final class UndoHistoryTests: XCTestCase {
    func testStartsWithNothingToUndoOrRedo() {
        var history = UndoHistory(initial: 0)
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
        XCTAssertNil(history.undo())
        XCTAssertNil(history.redo())
        XCTAssertEqual(history.present, 0)
    }

    func testCommitMakesUndoAvailable() {
        var history = UndoHistory(initial: 0)
        XCTAssertTrue(history.commit(1))
        XCTAssertEqual(history.present, 1)
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testCommittingTheCurrentStateIsANoOp() {
        var history = UndoHistory(initial: 0)
        XCTAssertFalse(history.commit(0))
        history.commit(1)
        XCTAssertFalse(history.commit(1))
        XCTAssertEqual(history.undoStack, [0])
    }

    func testUndoThenRedoWalksThroughStatesInOrder() {
        var history = UndoHistory(initial: 0)
        history.commit(1)
        history.commit(2)
        history.commit(3)

        XCTAssertEqual(history.undo(), 2)
        XCTAssertEqual(history.undo(), 1)
        XCTAssertEqual(history.undo(), 0)
        XCTAssertNil(history.undo())
        XCTAssertFalse(history.canUndo)
        XCTAssertTrue(history.canRedo)

        XCTAssertEqual(history.redo(), 1)
        XCTAssertEqual(history.redo(), 2)
        XCTAssertEqual(history.redo(), 3)
        XCTAssertNil(history.redo())
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(history.present, 3)
    }

    func testNewCommitAfterUndoClearsRedo() {
        var history = UndoHistory(initial: 0)
        history.commit(1)
        history.commit(2)
        _ = history.undo()
        XCTAssertTrue(history.canRedo)

        history.commit(9)

        XCTAssertFalse(history.canRedo)
        XCTAssertNil(history.redo())
        XCTAssertEqual(history.undo(), 1)
    }

    func testLimitDropsTheOldestStepsAndKeepsTheNewest() {
        var history = UndoHistory(initial: 0, limit: 3)
        for value in 1...6 { history.commit(value) }

        XCTAssertEqual(history.undoStack, [3, 4, 5])
        XCTAssertEqual(history.present, 6)
        XCTAssertEqual(history.undo(), 5)
        XCTAssertEqual(history.undo(), 4)
        XCTAssertEqual(history.undo(), 3)
        XCTAssertNil(history.undo())
    }

    func testDefaultLimitIsFifty() {
        var history = UndoHistory(initial: 0)
        for value in 1...80 { history.commit(value) }
        XCTAssertEqual(history.undoStack.count, 50)
        XCTAssertEqual(history.undoStack.first, 30)
        XCTAssertEqual(history.undoStack.last, 79)
    }

    func testResetClearsBothStacks() {
        var history = UndoHistory(initial: 0)
        history.commit(1)
        history.commit(2)
        _ = history.undo()

        history.reset(to: 7)

        XCTAssertEqual(history.present, 7)
        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
    }

    func testReplacePresentKeepsStacks() {
        var history = UndoHistory(initial: 0)
        history.commit(1)
        history.replacePresent(with: 5)
        XCTAssertEqual(history.present, 5)
        XCTAssertEqual(history.undo(), 0)
        XCTAssertEqual(history.redo(), 5)
    }
}
