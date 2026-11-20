import Foundation

// Draft transitions are independent of SwiftUI and disk storage.
enum SharedImportReviewState {
    static func review(_ id: String, selected: Bool, in draft: inout ImportDraft) {
        guard let index = draft.candidates.firstIndex(where: { $0.id == id }) else { return }
        draft.candidates[index].selected = selected
        var reviewed = draft.reviewedCandidateIDs ?? []
        if !reviewed.contains(id) { reviewed.append(id) }
        draft.reviewedCandidateIDs = reviewed
        draft.hasFinishedPieceReview = draft.candidates.allSatisfy { reviewed.contains($0.id) }
    }

    /// Steps back to the most recently reviewed piece so it can be decided again.
    static func undoLast(in draft: inout ImportDraft) {
        guard var reviewed = draft.reviewedCandidateIDs, let last = reviewed.popLast() else { return }
        draft.reviewedCandidateIDs = reviewed
        draft.hasFinishedPieceReview = false
        if let index = draft.candidates.firstIndex(where: { $0.id == last }) {
            draft.candidates[index].selected = false
        }
    }

    static func remove(_ id: String, from draft: inout ImportDraft) {
        draft.candidates.removeAll { $0.id == id }
        draft.removedCandidateIDs = Array(Set((draft.removedCandidateIDs ?? []) + [id]))
    }

    static func merge(_ found: [ImportCandidate], into draft: inout ImportDraft) {
        var known = Set(draft.candidates.map(\.id)).union(draft.removedCandidateIDs ?? [])
        let additions = found.filter { known.insert($0.id).inserted }
        draft.candidates += additions
        if !additions.isEmpty { draft.hasFinishedPieceReview = false }
        draft.status = .review
    }
}
