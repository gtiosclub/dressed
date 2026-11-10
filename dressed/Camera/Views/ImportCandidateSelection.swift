//
//  ImportCandidateSelection.swift
//  dressed
//
//  Created by Darsh Shetty on 10/13/26.
//

func selectedCandidates(from draft: ImportDraft) -> [ImportCandidate] {
    draft.candidates.filter { $0.selected }
}
