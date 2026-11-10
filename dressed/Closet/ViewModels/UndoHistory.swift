import Foundation

/// A bounded undo/redo history of value snapshots. It has no UI and no persistence.
///
/// `present` is the state the app is showing now. `commit` records a new state, `undo` and `redo`
/// move `present` along the two stacks and return the state to show.
struct UndoHistory<State: Equatable> {
    /// The state the app is showing now.
    private(set) var present: State
    /// Older states, oldest first. The last one is what `undo` returns.
    private(set) var undoStack: [State] = []
    /// States that were undone, most recently undone last. A new `commit` empties it.
    private(set) var redoStack: [State] = []
    /// The most undo steps kept. The oldest are dropped first.
    let limit: Int

    init(initial: State, limit: Int = 50) {
        self.present = initial
        self.limit = max(1, limit)
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Records `state` as the new present. Returns false, and changes nothing, if it equals the present.
    @discardableResult
    mutating func commit(_ state: State) -> Bool {
        guard state != present else { return false }
        undoStack.append(present)
        if undoStack.count > limit {
            undoStack.removeFirst(undoStack.count - limit)
        }
        present = state
        redoStack.removeAll()
        return true
    }

    /// Steps back and returns the state to show, or nil if there is nothing to undo.
    mutating func undo() -> State? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(present)
        present = previous
        return previous
    }

    /// Steps forward and returns the state to show, or nil if there is nothing to redo.
    mutating func redo() -> State? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(present)
        present = next
        return next
    }

    /// Replaces the present without touching either stack. Use it when the state that was actually
    /// shown differs from the one undo or redo returned.
    mutating func replacePresent(with state: State) {
        present = state
    }

    /// Forgets all history and starts again from `state`.
    mutating func reset(to state: State) {
        present = state
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
