import Foundation

struct PhotoCandidateObservation {
    let photoId: String
    let candidate: ImportCandidate
    let confidence: Double?
}

enum MultiPhotoCandidateGrouper {
    private struct GuessGroup {
        let identity: String
        var observations: [PhotoCandidateObservation]
        let firstIndex: Int
    }

    static func outfitCandidates(
        from observations: [PhotoCandidateObservation],
        importID: String
    ) -> [ImportCandidate] {
        var candidates: [ImportCandidate] = []
        var candidatePhotoIds: [Set<String>] = []
        var candidateIdentities: [String?] = []
        var identityOccurrences: [String: Int] = [:]

        for (index, observation) in observations.enumerated() {
            let identity = identityKey(for: observation.candidate)
            let matchingIndex = identity.flatMap { key in
                candidates.indices.first { candidateIndex in
                    candidateIdentities[candidateIndex] == key
                        && !candidatePhotoIds[candidateIndex].contains(observation.photoId)
                }
            }
            let sighting = makeSighting(observation, importID: importID, index: index)

            if let matchingIndex {
                candidates[matchingIndex].sightings?.append(sighting)
                candidatePhotoIds[matchingIndex].insert(observation.photoId)
                continue
            }

            let occurrence: Int
            let candidateID: String
            if let identity {
                occurrence = identityOccurrences[identity, default: 0]
                identityOccurrences[identity] = occurrence + 1
                candidateID = SharedImportDraftStore.stableID(
                    importID: importID,
                    part: "outfit:\(identity):\(occurrence)"
                )
            } else {
                candidateID = SharedImportDraftStore.stableID(
                    importID: importID,
                    part: "outfit:unmatched:\(observation.photoId):\(observation.candidate.id):\(index)"
                )
            }

            var candidate = observation.candidate
            candidate.id = candidateID
            candidate.sightings = [sighting]
            candidates.append(candidate)
            candidatePhotoIds.append([observation.photoId])
            candidateIdentities.append(identity)
        }

        return candidates
    }

    static func oneItemCandidate(
        from observations: [PhotoCandidateObservation],
        importID: String
    ) -> ImportCandidate? {
        guard !observations.isEmpty else { return nil }

        var groups: [GuessGroup] = []
        for (index, observation) in observations.enumerated() {
            if let identity = identityKey(for: observation.candidate),
               let groupIndex = groups.firstIndex(where: { $0.identity == identity }) {
                groups[groupIndex].observations.append(observation)
            } else {
                let identity = identityKey(for: observation.candidate)
                    ?? "unmatched:\(index):\(observation.candidate.id)"
                groups.append(GuessGroup(identity: identity, observations: [observation], firstIndex: index))
            }
        }

        let winningGroup = groups.max { first, second in
            let firstSupport = Set(first.observations.map(\.photoId)).count
            let secondSupport = Set(second.observations.map(\.photoId)).count
            if firstSupport != secondSupport { return firstSupport < secondSupport }

            let firstConfidence = averageConfidence(in: first.observations)
            let secondConfidence = averageConfidence(in: second.observations)
            if firstConfidence != secondConfidence { return firstConfidence < secondConfidence }
            return first.firstIndex > second.firstIndex
        }!

        let representative = winningGroup.observations.max {
            ($0.confidence ?? -1) < ($1.confidence ?? -1)
        }!
        var candidate = representative.candidate
        candidate.id = SharedImportDraftStore.stableID(importID: importID, part: "one-item")
        candidate.sightings = observations.enumerated().map { index, observation in
            makeSighting(observation, importID: importID, index: index)
        }
        return candidate
    }

    private static func identityKey(for candidate: ImportCandidate) -> String? {
        let name = candidate.name
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
        guard !name.isEmpty,
              !["piece", "item", "garment", "clothing", "accessory"].contains(name) else {
            return nil
        }
        return "\(candidate.category.rawValue.lowercased()):\(name)"
    }

    private static func averageConfidence(in observations: [PhotoCandidateObservation]) -> Double {
        let confidenceValues = observations.compactMap(\.confidence)
        guard !confidenceValues.isEmpty else { return 0 }
        return confidenceValues.reduce(0, +) / Double(confidenceValues.count)
    }

    private static func makeSighting(
        _ observation: PhotoCandidateObservation,
        importID: String,
        index: Int
    ) -> CandidateSighting {
        CandidateSighting(
            id: SharedImportDraftStore.stableID(
                importID: importID,
                part: "sighting:\(observation.photoId):\(observation.candidate.id):\(index)"
            ),
            photoId: observation.photoId,
            region: observation.candidate.region ?? NormalizedImageRegion(x: 0, y: 0, width: 1, height: 1),
            outline: observation.candidate.outline,
            category: observation.candidate.category,
            name: observation.candidate.name,
            confidence: observation.confidence,
            source: observation.candidate.suggestionSource
        )
    }
}