import Vision
import SwiftUI
import UIKit

struct MultiPhotoImportReviewView: View {
    let mode: ImportMode
    let importID: String
    let photos: [ReviewImage]
    @ObservedObject var closet: PrototypeClosetStore
    let onCancel: () -> Void
    let onSaved: () -> Void

    @State private var candidates: [ImportCandidate] = []
    @State private var detectedCandidates: [ImportCandidate] = []
    @State private var isAnalyzing = true
    @State private var isSaving = false
    @State private var analysisAttempt = 0
    @State private var currentPhotoIndex = 0
    @State private var analysisError: String?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Selected Photos") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                                photoThumbnail(photo.data)
                                    .overlay(alignment: .bottomLeading) {
                                        Text("Photo \(index + 1)")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(.ultraThinMaterial, in: Capsule())
                                            .padding(5)
                                    }
                            }
                        }
                    }
                    .frame(height: 116)
                }

                Section(mode == .oneItem ? "One Item Guess" : "Outfit Pieces") {
                    if isAnalyzing {
                        ProgressView("Analyzing photo \(currentPhotoIndex) of \(photos.count)…")
                    } else if candidates.isEmpty {
                        Text("No suggestions were produced. Try again or close this review.")
                            .foregroundStyle(.secondary)
                        Button("Try Again", action: retryAnalysis)
                    } else {
                        Text(mode == .oneItem
                             ? "Review the combined guess and the photos that support it."
                             : "Select the pieces you want to save. Repeated pieces across photos are grouped.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach($candidates) { $candidate in
                    Section("Suggested Piece") {
                        Toggle("Select this piece", isOn: $candidate.selected)
                        TextField("Piece name", text: $candidate.name)
                        Picker("Category", selection: $candidate.category) {
                            ForEach(ClothingCategory.allCases, id: \.self) { category in
                                Text(category.rawValue.capitalized).tag(category)
                            }
                        }

                        if mode == .oneOutfit, candidates.count > 1 {
                            Menu("Merge with…") {
                                ForEach(candidates.filter { $0.id != candidate.id }) { other in
                                    Button("Merge with \(other.name)") {
                                        mergeCandidate(candidate.id, into: other.id)
                                    }
                                }
                            }
                        }

                        let sightings = candidate.sightings ?? []
                        Text("Seen in \(sightings.count) photo\(sightings.count == 1 ? "" : "s")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if sightings.contains(where: { $0.source == "Recognition unavailable" || $0.source == "Review this photo" }) {
                            Text("Some photos need manual review. You can edit the guess or retry recognition.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Button("Retry Recognition", action: retryAnalysis)
                                .disabled(isAnalyzing || isSaving)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(sightings) { sighting in
                                    if let photo = photos.first(where: { $0.id == sighting.photoId }) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            photoThumbnail(photo.data)
                                            Text(photoLabel(for: sighting))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)

                                            if mode == .oneItem,
                                               sighting.name != candidate.name || sighting.category != candidate.category {
                                                Button("Use this guess") {
                                                    applyGuess(sighting, to: candidate.id)
                                                }
                                                .font(.caption2)
                                            }

                                            if mode == .oneOutfit, sightings.count > 1 {
                                                Button("Split into separate piece") {
                                                    split(sighting, from: candidate.id)
                                                }
                                                .font(.caption2)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if let analysisError {
                    Section {
                        Text(analysisError)
                            .foregroundStyle(.secondary)
                        Button("Try Again", action: retryAnalysis)
                            .disabled(isAnalyzing || isSaving)
                    }
                }

                if let saveError {
                    Section {
                        Text(saveError).foregroundStyle(.red)
                    }
                }

                if !candidates.isEmpty {
                    Section {
                        Button(isSaving ? "Saving…" : "Save Selected Pieces", action: saveSelectedPieces)
                            .disabled(isSaving || isAnalyzing || !candidates.contains(where: \.selected))
                    }
                }
            }
            .navigationTitle(mode == .oneItem ? "Review Item" : "Review Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
            .task(id: analysisAttempt) {
                await analyzePhotos()
            }
            .onDisappear {
                SharedImportDraftStore.removeAutomaticCutouts(for: detectedCandidates)
            }
        }
    }

    private func analyzePhotos() async {
        isAnalyzing = true
        currentPhotoIndex = 0
        analysisError = nil
        saveError = nil
        candidates = []
        SharedImportDraftStore.removeAutomaticCutouts(for: detectedCandidates)
        detectedCandidates = []

        var observations: [PhotoCandidateObservation] = []
        do {
            for (index, photo) in photos.enumerated() {
                try Task.checkCancellation()
                currentPhotoIndex = index + 1
                if mode == .oneItem {
                    let suggestion = try? await PrototypeGarmentRecognition.analyze(photo.data)
                    let candidate = ImportCandidate(
                        id: SharedImportDraftStore.stableID(importID: photo.id, part: "one-item-source"),
                        name: suggestion?.name ?? "Piece",
                        category: suggestion?.category ?? .other,
                        destination: .closet,
                        temporaryCutoutPath: nil,
                        region: nil,
                        suggestionSource: suggestion == nil ? "Recognition unavailable" : "On-device suggestion",
                        selected: false,
                        tags: [],
                        suggestedTags: []
                    )
                    observations.append(PhotoCandidateObservation(
                        photoId: photo.id,
                        candidate: candidate,
                        confidence: suggestion?.confidence
                    ))
                } else {
                    let found = try await AutomaticImportSuggestions.detect(
                        imageData: photo.data,
                        importID: photo.id
                    )
                    detectedCandidates.append(contentsOf: found)
                    for candidate in found {
                        try Task.checkCancellation()
                        let crop = try? SharedImportDraftStore.imageData(for: candidate, in: photo.data)
                        let featurePrint: VNFeaturePrintObservation?
                        if let crop {
                            featurePrint = await MultiPhotoCandidateGrouper.featurePrint(from: crop)
                        } else {
                            featurePrint = nil
                        }
                        observations.append(PhotoCandidateObservation(
                            photoId: photo.id,
                            candidate: candidate,
                            confidence: nil,
                            featurePrint: featurePrint
                        ))
                    }
                }
            }

            try Task.checkCancellation()
            if mode == .oneItem {
                if let candidate = MultiPhotoCandidateGrouper.oneItemCandidate(from: observations, importID: importID) {
                    candidates = [candidate]
                }
            } else {
                candidates = MultiPhotoCandidateGrouper.outfitCandidates(from: observations, importID: importID)
            }
            if candidates.isEmpty {
                analysisError = "Recognition did not return suggestions for these photos."
            }
        } catch is CancellationError {
            return
        } catch {
            analysisError = "Could not analyze the selected photos. Try again."
        }
        isAnalyzing = false
    }

    private func retryAnalysis() {
        analysisAttempt += 1
    }

    private func saveSelectedPieces() {
        guard !isSaving else { return }
        let selected = candidates.filter(\.selected)
        guard !selected.isEmpty else { return }

        isSaving = true
        saveError = nil
        var newlySaved: [String] = []
        do {
            for candidate in selected {
                guard !candidate.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let sighting = sourceSighting(for: candidate),
                      let photo = photos.first(where: { $0.id == sighting.photoId }) else {
                    throw PrototypeImportError.emptyName
                }

                var sourceCandidate = candidate
                sourceCandidate.region = sighting.region
                sourceCandidate.outline = sighting.outline
                sourceCandidate.temporaryCutoutPath = nil
                let imageData = try SharedImportDraftStore.imageData(for: sourceCandidate, in: photo.data)
                let existed = closet.item(id: candidate.id) != nil
                try closet.save(
                    imageData: imageData,
                    draftId: candidate.id,
                    name: candidate.name,
                    category: candidate.category
                )
                if !existed { newlySaved.append(candidate.id) }
            }
            onSaved()
        } catch {
            for id in newlySaved { try? closet.delete(id: id) }
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    private func sourceSighting(for candidate: ImportCandidate) -> CandidateSighting? {
        guard let sightings = candidate.sightings, !sightings.isEmpty else { return nil }
        return sightings.first(where: { $0.name == candidate.name && $0.category == candidate.category })
            ?? sightings.first
    }

    private func applyGuess(_ sighting: CandidateSighting, to candidateID: String) {
        guard let index = candidates.firstIndex(where: { $0.id == candidateID }) else { return }
        candidates[index].name = sighting.name
        candidates[index].category = sighting.category
    }

    private func split(_ sighting: CandidateSighting, from candidateID: String) {
        guard let index = candidates.firstIndex(where: { $0.id == candidateID }),
              let result = MultiPhotoCandidateGrouper.splitSighting(
                  sighting,
                  from: candidates[index],
                  importID: importID
              ) else { return }
        candidates[index] = result.updated
        candidates.insert(result.separated, at: index + 1)
    }

    private func mergeCandidate(_ sourceID: String, into targetID: String) {
        guard let source = candidates.first(where: { $0.id == sourceID }),
              let target = candidates.first(where: { $0.id == targetID }),
              let merged = MultiPhotoCandidateGrouper.mergeCandidates(source, into: target) else { return }
        candidates.removeAll { $0.id == sourceID }
        guard let targetIndex = candidates.firstIndex(where: { $0.id == targetID }) else { return }
        candidates[targetIndex] = merged
    }

    private func photoLabel(for sighting: CandidateSighting) -> String {
        let photoIndex = photos.firstIndex(where: { $0.id == sighting.photoId }).map { $0 + 1 } ?? 0
        let detail = sighting.confidence.map { "\(Int(($0 * 100).rounded()))% confidence" }
            ?? sighting.source
            ?? "Confidence unavailable"
        return "Photo \(photoIndex): \(sighting.name) · \(detail)"
    }

    private func photoThumbnail(_ data: Data) -> some View {
        Group {
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .frame(width: 92, height: 92)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
