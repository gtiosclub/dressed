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
    // Per-photo results, so a retry or photo removal never re-runs the others.
    @State private var resultsByPhoto: [String: [PhotoCandidateObservation]] = [:]
    @State private var cutoutsByPhoto: [String: [ImportCandidate]] = [:]
    @State private var failedPhotoIds: Set<String> = []
    @State private var removedPhotoIds: Set<String> = []
    @State private var isAnalyzing = true
    @State private var isSaving = false
    @State private var analysisAttempt = 0
    @State private var currentPhotoIndex = 0
    @State private var pendingPhotoCount = 0
    @State private var analysisError: String?
    @State private var saveError: String?
    @State private var latencyByPhoto: [String: Double] = [:]
    @State private var evaluationExportMessage: String?

    private var activePhotos: [ReviewImage] {
        photos.filter { !removedPhotoIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Selected Photos") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(activePhotos) { photo in
                                photoThumbnail(photo.data)
                                    .overlay(alignment: .bottomLeading) {
                                        Text(failedPhotoIds.contains(photo.id)
                                             ? "Photo \(photoNumber(photo.id)) · Not recognized"
                                             : "Photo \(photoNumber(photo.id))")
                                            .font(.caption2.weight(.semibold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(.ultraThinMaterial, in: Capsule())
                                            .padding(5)
                                    }
                                    .overlay(alignment: .topTrailing) {
                                        if activePhotos.count > 1 {
                                            Button {
                                                removePhoto(photo.id)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .symbolRenderingMode(.palette)
                                                    .foregroundStyle(.white, .black.opacity(0.65))
                                            }
                                            .buttonStyle(.plain)
                                            .padding(4)
                                            .disabled(isAnalyzing || isSaving)
                                            .accessibilityLabel("Remove photo \(photoNumber(photo.id))")
                                        }
                                    }
                            }
                        }
                    }
                    .frame(height: 116)

                    if !failedPhotoIds.isEmpty, !isAnalyzing {
                        Button(failedPhotoIds.count == 1
                               ? "Retry Unrecognized Photo"
                               : "Retry \(failedPhotoIds.count) Unrecognized Photos",
                               action: retryAnalysis)
                            .disabled(isSaving)
                    }
                }

                Section(mode == .oneItem ? "One Item Guess" : "Outfit Pieces") {
                    if isAnalyzing {
                        ProgressView("Analyzing photo \(currentPhotoIndex) of \(pendingPhotoCount)…")
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
                        if mode == .oneItem, MultiPhotoCandidateGrouper.photosDisagree(candidate) {
                            Label("Photos disagree on the category. Choose one below.",
                                  systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
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

                #if DEBUG
                if !isAnalyzing, !resultsByPhoto.isEmpty {
                    Section("Developer") {
                        Button("Export Evaluation JSON", action: exportEvaluation)
                        if let evaluationExportMessage {
                            Text(evaluationExportMessage)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
                #endif

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
                SharedImportDraftStore.removeAutomaticCutouts(for: cutoutsByPhoto.values.flatMap { $0 })
            }
        }
    }

    private func analyzePhotos() async {
        isAnalyzing = true
        analysisError = nil
        saveError = nil
        let pending = activePhotos.filter { resultsByPhoto[$0.id] == nil || failedPhotoIds.contains($0.id) }
        pendingPhotoCount = pending.count
        currentPhotoIndex = 0

        // One photo at a time keeps the Debug recognition bridge under its rate limit.
        for (index, photo) in pending.enumerated() {
            guard !Task.isCancelled else { return }
            currentPhotoIndex = index + 1
            SharedImportDraftStore.removeAutomaticCutouts(for: cutoutsByPhoto[photo.id] ?? [])
            let started = ContinuousClock.now
            let result = await analyze(photo)
            latencyByPhoto[photo.id] = milliseconds(ContinuousClock.now - started)
            guard !Task.isCancelled else {
                SharedImportDraftStore.removeAutomaticCutouts(for: result.cutouts)
                return
            }
            resultsByPhoto[photo.id] = result.observations
            cutoutsByPhoto[photo.id] = result.cutouts
            if result.failed {
                failedPhotoIds.insert(photo.id)
            } else {
                failedPhotoIds.remove(photo.id)
            }
        }

        regroup()
        if candidates.isEmpty {
            analysisError = "Recognition did not return suggestions for these photos."
        }
        isAnalyzing = false
    }

    private func analyze(
        _ photo: ReviewImage
    ) async -> (observations: [PhotoCandidateObservation], cutouts: [ImportCandidate], failed: Bool) {
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
            let observation = PhotoCandidateObservation(
                photoId: photo.id,
                candidate: candidate,
                confidence: suggestion?.confidence
            )
            return ([observation], [], suggestion == nil)
        }

        let found = (try? await AutomaticImportSuggestions.detect(imageData: photo.data, importID: photo.id)) ?? []
        var observations: [PhotoCandidateObservation] = []
        for candidate in found {
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
        // Every detector stage fell through to the generic "Review this photo" piece.
        let failed = found.allSatisfy { $0.suggestionSource == "Review this photo" }
        return (observations, found, failed)
    }

    /// Rebuilds candidates from the cached per-photo results. Selection, and in
    /// outfit mode edited names and categories, carry over by stable candidate ID.
    /// Manual splits and merges are not replayed.
    private func regroup() {
        let observations = activePhotos.flatMap { resultsByPhoto[$0.id] ?? [] }
        let previous = Dictionary(candidates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var regrouped: [ImportCandidate]
        if mode == .oneItem {
            regrouped = MultiPhotoCandidateGrouper.oneItemCandidate(from: observations, importID: importID)
                .map { [$0] } ?? []
        } else {
            regrouped = MultiPhotoCandidateGrouper.outfitCandidates(from: observations, importID: importID)
        }
        for index in regrouped.indices {
            guard let old = previous[regrouped[index].id] else { continue }
            regrouped[index].selected = old.selected
            if mode == .oneOutfit {
                regrouped[index].name = old.name
                regrouped[index].category = old.category
            }
        }
        candidates = regrouped
    }

    private func removePhoto(_ photoId: String) {
        guard activePhotos.count > 1 else { return }
        removedPhotoIds.insert(photoId)
        failedPhotoIds.remove(photoId)
        SharedImportDraftStore.removeAutomaticCutouts(for: cutoutsByPhoto[photoId] ?? [])
        cutoutsByPhoto[photoId] = nil
        resultsByPhoto[photoId] = nil

        if mode == .oneItem {
            // Re-vote so the removed photo no longer influences the guess.
            regroup()
        } else {
            // Keep the person's edits, splits and merges; drop only this photo's evidence.
            candidates = candidates.compactMap { candidate in
                var candidate = candidate
                candidate.sightings = candidate.sightings?.filter { $0.photoId != photoId }
                return (candidate.sightings ?? []).isEmpty ? nil : candidate
            }
        }
    }

    private func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1e15
    }

    #if DEBUG
    /// Writes the automatic grouping (before any manual edits) in the format read by
    /// backend/recognition/evaluate_multiphoto.py. Labels and boxes only, no images.
    private func exportEvaluation() {
        let observations = activePhotos.flatMap { resultsByPhoto[$0.id] ?? [] }
        let automatic = mode == .oneItem
            ? MultiPhotoCandidateGrouper.oneItemCandidate(from: observations, importID: importID).map { [$0] } ?? []
            : MultiPhotoCandidateGrouper.outfitCandidates(from: observations, importID: importID)
        let export = MultiPhotoEvaluationExport(
            method: "in-house",
            importId: importID,
            mode: mode.rawValue,
            photos: activePhotos.map { .init(photoId: $0.id) },
            latencyMs: Int(activePhotos.compactMap { latencyByPhoto[$0.id] }.reduce(0, +).rounded()),
            photosAnalyzed: activePhotos.count,
            candidates: automatic.map { candidate in
                .init(
                    category: candidate.category.rawValue,
                    name: candidate.name,
                    sightings: (candidate.sightings ?? []).map { sighting in
                        .init(
                            photoId: sighting.photoId,
                            category: sighting.category.rawValue,
                            name: sighting.name,
                            confidence: sighting.confidence,
                            source: sighting.source,
                            boundingBox: mode == .oneOutfit ? sighting.region : nil
                        )
                    }
                )
            }
        )
        do {
            let folder = try FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("MultiPhotoEvaluation", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appendingPathComponent("\(mode.rawValue)-\(importID).json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(export).write(to: file, options: .atomic)
            evaluationExportMessage = "Saved \(file.path)"
            print("[MultiPhotoEvaluation] \(file.path)")
        } catch {
            evaluationExportMessage = "Export failed: \(error.localizedDescription)"
        }
    }
    #endif

    private func photoNumber(_ photoId: String) -> Int {
        (photos.firstIndex(where: { $0.id == photoId }) ?? 0) + 1
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

#if DEBUG
// Predictions-file shape for backend/recognition/evaluate_multiphoto.py.
private struct MultiPhotoEvaluationExport: Encodable {
    struct Photo: Encodable {
        let photoId: String
    }

    struct Sighting: Encodable {
        let photoId: String
        let category: String
        let name: String
        let confidence: Double?
        let source: String?
        let boundingBox: NormalizedImageRegion?
    }

    struct Candidate: Encodable {
        let category: String
        let name: String
        let sightings: [Sighting]
    }

    let method: String
    let importId: String
    let mode: String
    let photos: [Photo]
    let latencyMs: Int
    let photosAnalyzed: Int
    let candidates: [Candidate]
}
#endif
