import Foundation
import Vision

struct PhotoCandidateObservation {
    let photoId: String
    let candidate: ImportCandidate
    let confidence: Double?
    let featurePrint: VNFeaturePrintObservation?

    init(
        photoId: String,
        candidate: ImportCandidate,
        confidence: Double?,
        featurePrint: VNFeaturePrintObservation? = nil
    ) {
        self.photoId = photoId
        self.candidate = candidate
        self.confidence = confidence
        self.featurePrint = featurePrint
    }
}

enum MultiPhotoCandidateGrouper {
    static let defaultFeatureDistanceThreshold: Float = 0.5

    static func outfitCandidates(
        from observations: [PhotoCandidateObservation],
        importID: String,
        featureDistanceThreshold: Float = defaultFeatureDistanceThreshold
    ) -> [ImportCandidate] {
        var candidates: [ImportCandidate] = []
        var candidatePhotoIds: [Set<String>] = []
        var candidateIdentities: [String?] = []
        var candidateFeaturePrints: [[VNFeaturePrintObservation]] = []
        var identityOccurrences: [String: Int] = [:]

        for (index, observation) in observations.enumerated() {
            let identity = identityKey(for: observation.candidate)
            let matchingIndex = candidates.indices.first { candidateIndex in
                guard candidates[candidateIndex].category == observation.candidate.category,
                      !candidatePhotoIds[candidateIndex].contains(observation.photoId) else { return false }
                if let featurePrint = observation.featurePrint,
                   candidateFeaturePrints[candidateIndex].contains(where: {
                       areSimilar(featurePrint, $0, threshold: featureDistanceThreshold)
                   }) {
                    return true
                }
                let hasComparableFeaturePrint = observation.featurePrint != nil
                    && !candidateFeaturePrints[candidateIndex].isEmpty
                return !hasComparableFeaturePrint
                    && identity != nil
                    && candidateIdentities[candidateIndex] == identity
            }
            let sighting = makeSighting(observation, importID: importID, index: index)

            if let matchingIndex {
                candidates[matchingIndex].sightings?.append(sighting)
                candidatePhotoIds[matchingIndex].insert(observation.photoId)
                if let featurePrint = observation.featurePrint {
                    candidateFeaturePrints[matchingIndex].append(featurePrint)
                }
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
            candidateFeaturePrints.append(observation.featurePrint.map { [$0] } ?? [])
        }

        return candidates
    }

    static func oneItemCandidate(
        from observations: [PhotoCandidateObservation],
        importID: String
    ) -> ImportCandidate? {
        guard !observations.isEmpty else { return nil }

        // Generic fallbacks ("Piece") only vote when nothing was recognized.
        let recognized = observations.filter { identityKey(for: $0.candidate) != nil }
        let voters = recognized.isEmpty ? observations : recognized

        // Confidence-weighted category vote, then a name vote inside the winning
        // category. Ties keep the earliest photo's guess.
        let winningCategory = weightedWinner(voters) { $0.candidate.category.rawValue }
        let inCategory = voters.filter { $0.candidate.category.rawValue == winningCategory }
        let winningName = weightedWinner(inCategory) { identityKey(for: $0.candidate) ?? $0.candidate.name }
        let winningGroup = inCategory.filter {
            (identityKey(for: $0.candidate) ?? $0.candidate.name) == winningName
        }

        // Highest confidence stands in for "clearest"; larger region breaks ties.
        let representative = winningGroup.max { first, second in
            let firstConfidence = first.confidence ?? -1
            let secondConfidence = second.confidence ?? -1
            if firstConfidence != secondConfidence { return firstConfidence < secondConfidence }
            return regionArea(first.candidate.region) < regionArea(second.candidate.region)
        }!
        var candidate = representative.candidate
        candidate.id = SharedImportDraftStore.stableID(importID: importID, part: "one-item")
        let representativeIndex = observations.firstIndex {
            $0.photoId == representative.photoId && $0.candidate.id == representative.candidate.id
        } ?? 0
        let orderedObservations = [observations[representativeIndex]]
            + observations.enumerated().compactMap { index, observation in
                index == representativeIndex ? nil : observation
            }
        candidate.sightings = orderedObservations.enumerated().map { index, observation in
            makeSighting(observation, importID: importID, index: index)
        }
        return candidate
    }

    static func splitSighting(
        _ sighting: CandidateSighting,
        from candidate: ImportCandidate,
        importID: String
    ) -> (updated: ImportCandidate, separated: ImportCandidate)? {
        guard var sightings = candidate.sightings,
              sightings.count > 1,
              let index = sightings.firstIndex(where: { $0.id == sighting.id }) else {
            return nil
        }

        sightings.remove(at: index)
        var updated = candidate
        updated.sightings = sightings
        if sameRegion(candidate.region, sighting.region), let remaining = sightings.first {
            // The moved sighting supplied this candidate's image area.
            updated.region = remaining.region
            updated.outline = remaining.outline
            updated.temporaryCutoutPath = nil
        }

        var separated = candidate
        separated.id = SharedImportDraftStore.stableID(
            importID: importID,
            part: "split:\(candidate.id):\(sighting.id)"
        )
        separated.name = sighting.name
        separated.category = sighting.category
        separated.region = sighting.region
        separated.outline = sighting.outline
        separated.temporaryCutoutPath = nil
        separated.selected = false
        separated.sightings = [sighting]
        return (updated, separated)
    }

    static func mergeCandidates(
        _ source: ImportCandidate,
        into target: ImportCandidate
    ) -> ImportCandidate? {
        guard source.id != target.id else { return nil }
        var merged = target
        let existingSightingIds = Set(merged.sightings?.map(\.id) ?? [])
        merged.sightings = (merged.sightings ?? []) + (source.sightings ?? []).filter {
            !existingSightingIds.contains($0.id)
        }
        merged.selected = target.selected || source.selected
        return merged
    }

    static func featurePrint(from imageData: Data) async -> VNFeaturePrintObservation? {
        await Task.detached(priority: .userInitiated) {
            let request = try? VisionRequestRunner.perform(
                { VNGenerateImageFeaturePrintRequest() },
                on: imageData
            )
            return request?.results?.first
        }.value
    }

    private static func areSimilar(
        _ first: VNFeaturePrintObservation,
        _ second: VNFeaturePrintObservation,
        threshold: Float
    ) -> Bool {
        var distance: Float = .greatestFiniteMagnitude
        do {
            try first.computeDistance(&distance, to: second)
            return distance <= threshold
        } catch {
            return false
        }
    }

    /// True when recognized photos point to more than one category, so review
    /// should ask the person to choose instead of trusting the vote.
    static func photosDisagree(_ candidate: ImportCandidate) -> Bool {
        let categories = (candidate.sightings ?? [])
            .filter { identityKey(name: $0.name, category: $0.category) != nil }
            .map(\.category)
        return Set(categories).count > 1
    }

    private static func weightedWinner(
        _ observations: [PhotoCandidateObservation],
        key: (PhotoCandidateObservation) -> String
    ) -> String {
        var weights: [String: Double] = [:]
        var order: [String] = []
        for observation in observations {
            let value = key(observation)
            if weights[value] == nil { order.append(value) }
            // Missing confidence counts as a neutral half vote.
            weights[value, default: 0] += observation.confidence ?? 0.5
        }
        let best = weights.values.max() ?? 0
        return order.first { weights[$0] == best } ?? ""
    }

    private static func sameRegion(_ first: NormalizedImageRegion?, _ second: NormalizedImageRegion) -> Bool {
        guard let first else { return false }
        return first.x == second.x && first.y == second.y
            && first.width == second.width && first.height == second.height
    }

    private static func regionArea(_ region: NormalizedImageRegion?) -> Double {
        guard let region else { return 1 }
        return region.width * region.height
    }

    private static func identityKey(for candidate: ImportCandidate) -> String? {
        identityKey(name: candidate.name, category: candidate.category)
    }

    private static func identityKey(name rawName: String, category: ClothingCategory) -> String? {
        let name = rawName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .joined(separator: " ")
        guard !name.isEmpty,
              !["piece", "item", "garment", "clothing", "accessory"].contains(name) else {
            return nil
        }
        return "\(category.rawValue.lowercased()):\(name)"
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