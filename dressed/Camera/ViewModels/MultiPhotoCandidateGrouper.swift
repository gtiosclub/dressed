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

    private struct GuessGroup {
        let identity: String
        var observations: [PhotoCandidateObservation]
        let firstIndex: Int
    }

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
            let request = VNGenerateImageFeaturePrintRequest()
            guard (try? VNImageRequestHandler(data: imageData).perform([request])) != nil else { return nil }
            return request.results?.first
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