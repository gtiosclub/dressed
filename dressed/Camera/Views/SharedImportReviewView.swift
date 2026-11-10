import SwiftUI
import UIKit

struct SharedImportReviewView: View {
    let image: ReviewImage
    let ownerId: String
    @ObservedObject var closet: PrototypeClosetStore
    let onLater: () -> Void
    let onDiscard: () -> Void
    let onSaved: () -> Void

    @StateObject private var outfits: PrototypeOutfitStore
    @State private var draft: ImportDraft?
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var detectionTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var cropCandidateID: String?
    @State private var confirmsDiscard = false

    init(image: ReviewImage, ownerId: String, closet: PrototypeClosetStore,
         onLater: @escaping () -> Void, onDiscard: @escaping () -> Void,
         onSaved: @escaping () -> Void) {
        self.image = image
        self.ownerId = ownerId
        self.closet = closet
        self.onLater = onLater
        self.onDiscard = onDiscard
        self.onSaved = onSaved
        _outfits = StateObject(wrappedValue: PrototypeOutfitStore(ownerId: ownerId))
    }

    private var selectedCount: Int { draft?.candidates.filter(\.selected).count ?? 0 }
    private var reviewedCount: Int {
        let reviewed = Set(draft?.reviewedCandidateIDs ?? [])
        return draft?.candidates.filter { reviewed.contains($0.id) }.count ?? 0
    }
    private var mode: ImportSaveMode { draft?.saveMode ?? .outfit }
    private var currentCandidate: ImportCandidate? {
        guard let draft, draft.hasFinishedPieceReview != true else { return nil }
        let reviewed = Set(draft.reviewedCandidateIDs ?? [])
        return draft.candidates.first { !reviewed.contains($0.id) }
    }
    private var canSave: Bool {
        guard let draft else { return false }
        return !isSaving && !isProcessing && selectedCount > 0
            && draft.candidates.filter(\.selected).allSatisfy {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            && (mode == .individualPieces
                || !(draft.outfitName ?? "Shared outfit").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                if isProcessing {
                    Section {
                        ProgressView("Finding possible pieces…")
                    }
                }
                if let candidate = currentCandidate {
                    Section {
                        candidateImage(candidate)
                            .resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 280)
                            .accessibilityLabel("Detected piece preview")
                        candidateDetails(candidate)
                        Button("Approve") { review(candidate, selected: true) }
                            .accessibilityIdentifier("sharedImport.approve")
                            .disabled(candidate.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Skip") { review(candidate, selected: false) }
                            .accessibilityIdentifier("sharedImport.skip")
                    } header: {
                        Text("Review piece \(reviewedCount + 1) of \(draft?.candidates.count ?? 0)")
                    }
                } else if let draft {
                    Section {
                        if let original = UIImage(data: image.data) {
                            Image(uiImage: original)
                                .resizable().scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 180)
                                .accessibilityLabel("Shared image to review")
                        }
                        Text("Nothing enters your closet until you confirm the import.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Pieces in Image") {
                        if draft.candidates.isEmpty {
                            Text("No pieces found. Use Find more to add one with lasso, or try recognition again.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(selectedCount) of \(draft.candidates.count) pieces selected")
                                .foregroundStyle(.secondary)
                        }
                        Button("Find more", systemImage: "lasso", action: addManualCandidate)
                            .accessibilityIdentifier("sharedImport.findMore")
                            .disabled(isProcessing)
                        if draft.candidates.isEmpty {
                            Button("Try Recognition Again", systemImage: "arrow.clockwise", action: processImage)
                                .disabled(isProcessing)
                        }
                    }
                    ForEach(draft.candidates) { candidate in
                        Section {
                            ImportCandidateRow(name: candidate.name,
                                               thumbnail: candidateImage(candidate),
                                               isSelected: selectedBinding(for: candidate.id))
                            candidateDetails(candidate)
                            Button("Remove", role: .destructive) { remove(candidate) }
                        }
                    }
                    Section("Save Reviewed Selection") {
                        Picker("Import", selection: Binding(
                            get: { mode },
                            set: { value in mutateDraft { $0.saveMode = value } }
                        )) {
                            Text("As outfit").tag(ImportSaveMode.outfit)
                            Text("As individual pieces").tag(ImportSaveMode.individualPieces)
                        }
                        .accessibilityIdentifier("sharedImport.saveMode")
                        if mode == .outfit {
                            TextField("Outfit name", text: Binding(
                                get: { self.draft?.outfitName ?? "Shared outfit" },
                                set: { name in mutateDraft { $0.outfitName = name } }
                            ))
                            Text("Saves selected pieces to your closet and groups them in an outfit.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Button(isSaving ? "Saving…" : (mode == .outfit ? "Import as outfit" : "Import as individual pieces"),
                               action: confirm)
                            .accessibilityIdentifier("sharedImport.confirm")
                            .disabled(!canSave)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                        if draft == nil {
                            Button("Retry", action: loadDraft)
                        }
                    }
                }
            }
            .disabled(isSaving)
            .navigationTitle("Review Shared Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { detectionTask?.cancel(); onLater() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Discard", role: .destructive) { confirmsDiscard = true }
                        .disabled(isSaving)
                }
            }
            .confirmationDialog("Discard this shared image?", isPresented: $confirmsDiscard) {
                Button("Discard Image", role: .destructive) { detectionTask?.cancel(); onDiscard() }
            } message: {
                Text("The draft and its temporary image will be removed.")
            }
            .sheet(isPresented: Binding(
                get: { cropCandidateID != nil },
                set: { if !$0 { cropCandidateID = nil } }
            )) {
                if let id = cropCandidateID,
                   let candidate = draft?.candidates.first(where: { $0.id == id }) {
                    SharedImageRegionEditor(imageData: image.data, initial: candidate.region,
                                            initialOutline: candidate.outline) { region, outline in
                        if mutateCandidate(id: id, { $0.region = region; $0.outline = outline; $0.temporaryCutoutPath = nil }) {
                            SharedImportDraftStore.removeAutomaticCutouts(for: [candidate])
                            cropCandidateID = nil
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .task { loadDraft() }
            .onDisappear { detectionTask?.cancel() }
        }
    }

    @ViewBuilder
    private func candidateDetails(_ candidate: ImportCandidate) -> some View {
        TextField("Piece name", text: Binding(
            get: { draft?.candidates.first(where: { $0.id == candidate.id })?.name ?? "" },
            set: { name in mutateCandidate(id: candidate.id) { $0.name = name } }
        ))
        Picker("Category", selection: Binding(
            get: { draft?.candidates.first(where: { $0.id == candidate.id })?.category ?? .other },
            set: { category in mutateCandidate(id: candidate.id) { $0.category = category } }
        )) {
            ForEach(ClothingCategory.allCases, id: \.self) { category in
                Text(category.rawValue.capitalized).tag(category)
            }
        }
        Button("Adjust Image Region") { cropCandidateID = candidate.id }
        if let source = candidate.suggestionSource {
            Text(source).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func review(_ candidate: ImportCandidate, selected: Bool) {
        mutateDraft { SharedImportReviewState.review(candidate.id, selected: selected, in: &$0) }
    }

    private func remove(_ candidate: ImportCandidate) {
        if mutateDraft({ SharedImportReviewState.remove(candidate.id, from: &$0) }) {
            SharedImportDraftStore.removeAutomaticCutouts(for: [candidate])
        }
    }

    private func loadDraft() {
        guard draft == nil else { return }
        do {
            var loaded = try SharedImportDraftStore.loadOrCreate(image: image, ownerId: ownerId)
            if loaded.status == .saved { onSaved(); return }
            if loaded.status == .saving || loaded.status == .processing {
                loaded.status = loaded.candidates.isEmpty ? .received : .review
                try SharedImportDraftStore.save(loaded)
            }
            draft = loaded
            errorMessage = nil
            if loaded.status == .received { processImage() }
        } catch { errorMessage = error.localizedDescription }
    }

    private func processImage() {
        guard !isProcessing, draft?.candidates.isEmpty == true,
              mutateDraft({ $0.status = .processing }) else { return }
        isProcessing = true
        detectionTask?.cancel()
        detectionTask = Task {
            defer { isProcessing = false }
            do {
                // Consume the existing recognition service; background recovery and
                // pipeline changes belong to #208 / #228.
                let found = try await AutomaticImportSuggestions.detect(imageData: image.data, importID: image.id)
                guard !Task.isCancelled else {
                    SharedImportDraftStore.removeAutomaticCutouts(for: found)
                    return
                }
                let removed = Set(draft?.removedCandidateIDs ?? [])
                let usable = found.filter {
                    !removed.contains($0.id) && $0.suggestionSource != "Review this photo"
                }
                let usableIDs = Set(usable.map(\.id))
                SharedImportDraftStore.removeAutomaticCutouts(for: found.filter { !usableIDs.contains($0.id) })
                if !mutateDraft({ SharedImportReviewState.merge(usable, into: &$0) }) {
                    SharedImportDraftStore.removeAutomaticCutouts(for: usable)
                }
            } catch is CancellationError {
                // The processing status is recovered on the next open.
            } catch {
                guard !Task.isCancelled else { return }
                mutateDraft { $0.status = .review }
                errorMessage = "Could not recognize pieces. Use Find more to add them with lasso, or try again."
            }
        }
    }

    private func addManualCandidate() {
        guard draft != nil else { return }
        let candidate = ImportCandidate(id: UUID().uuidString, name: "", category: .other,
                                        destination: .closet, temporaryCutoutPath: nil,
                                        region: nil, suggestionSource: nil, selected: false,
                                        tags: [], suggestedTags: [])
        if mutateDraft({ $0.candidates.append(candidate); $0.status = .review }) {
            // Keep the combined review visible while correcting a missed piece.
            cropCandidateID = candidate.id
        }
    }

    @discardableResult
    private func mutateDraft(_ change: (inout ImportDraft) -> Void) -> Bool {
        guard var updated = draft else { return false }
        change(&updated)
        do {
            try SharedImportDraftStore.save(updated)
            draft = updated
            errorMessage = nil
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    @discardableResult
    private func mutateCandidate(id: String, _ change: (inout ImportCandidate) -> Void) -> Bool {
        mutateDraft { value in
            guard let index = value.candidates.firstIndex(where: { $0.id == id }) else { return }
            change(&value.candidates[index])
        }
    }

    private func selectedBinding(for id: String) -> Binding<Bool> {
        Binding(get: { draft?.candidates.first(where: { $0.id == id })?.selected ?? false },
                set: { selection in mutateCandidate(id: id) { $0.selected = selection } })
    }

    private func candidateImage(_ candidate: ImportCandidate) -> Image {
        if let data = try? SharedImportDraftStore.imageData(for: candidate, in: image.data),
           let preview = UIImage(data: data) { return Image(uiImage: preview) }
        return Image(systemName: "photo")
    }

    private func confirm() {
        guard let current = draft, canSave else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let coordinator = SharedImportSaveCoordinator(closet: closet, outfits: outfits)
            _ = try coordinator.confirm(draft: current, imageData: image.data,
                                        outfitName: current.outfitName ?? "Shared outfit", mode: mode)
            guard mutateDraft({ $0.status = .saved }) else { return }
            onSaved()
        } catch { errorMessage = error.localizedDescription }
    }
}

struct SharedImageRegionEditor: View {
    let imageData: Data
    let onSave: (NormalizedImageRegion?, [NormalizedImagePoint]?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var region: NormalizedImageRegion
    @State private var outline: [NormalizedImagePoint]?
    @State private var drawing: [NormalizedImagePoint] = []
    @State private var isDrawingOutline = false

    init(imageData: Data, initial: NormalizedImageRegion?,
         initialOutline: [NormalizedImagePoint]? = nil,
         onSave: @escaping (NormalizedImageRegion?, [NormalizedImagePoint]?) -> Void) {
        self.imageData = imageData
        self.onSave = onSave
        _region = State(initialValue: initial ?? NormalizedImageRegion(x: 0, y: 0, width: 1, height: 1))
        _outline = State(initialValue: initialOutline)
        _isDrawingOutline = State(initialValue: initialOutline != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let image = UIImage(data: imageData) {
                    GeometryReader { geometry in
                        let scale = min(geometry.size.width / image.size.width,
                                        geometry.size.height / image.size.height)
                        let display = CGSize(width: image.size.width * scale,
                                             height: image.size.height * scale)
                        let origin = CGPoint(x: (geometry.size.width - display.width) / 2,
                                             y: (geometry.size.height - display.height) / 2)
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: display.width, height: display.height)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        if isDrawingOutline {
                            Path { path in
                                for (index, point) in (drawing.isEmpty ? outline ?? [] : drawing).enumerated() {
                                    let location = CGPoint(x: origin.x + point.x * display.width,
                                                           y: origin.y + point.y * display.height)
                                    if index == 0 { path.move(to: location) } else { path.addLine(to: location) }
                                }
                                if drawing.isEmpty && outline != nil { path.closeSubpath() }
                            }
                            .stroke(.yellow, lineWidth: 3)
                        } else {
                            Rectangle()
                                .stroke(.yellow, lineWidth: 3)
                                .frame(width: display.width * region.width,
                                       height: display.height * region.height)
                                .position(x: origin.x + display.width * (region.x + region.width / 2),
                                          y: origin.y + display.height * (region.y + region.height / 2))
                        }
                        if isDrawingOutline {
                            Color.clear
                                .contentShape(Rectangle())
                                .gesture(DragGesture(minimumDistance: 5)
                                    .onChanged { value in
                                        let x = (value.location.x - origin.x) / display.width
                                        let y = (value.location.y - origin.y) / display.height
                                        guard (0...1).contains(x), (0...1).contains(y) else { return }
                                        if drawing.isEmpty { outline = nil }
                                        drawing.append(NormalizedImagePoint(x: x, y: y))
                                    }
                                    .onEnded { _ in finishOutline() })
                                .simultaneousGesture(SpatialTapGesture().onEnded { value in
                                    let x = (value.location.x - origin.x) / display.width
                                    let y = (value.location.y - origin.y) / display.height
                                    guard (0...1).contains(x), (0...1).contains(y) else { return }
                                    if drawing.isEmpty { outline = nil }
                                    drawing.append(NormalizedImagePoint(x: x, y: y))
                                })
                        }
                    }
                    .frame(height: 360)
                }
                Section("Image Region") {
                    Picker("Selection", selection: $isDrawingOutline) {
                        Text("Rectangle").tag(false)
                        Text("Draw Outline").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if isDrawingOutline {
                        Text("Trace with your finger or tap points around one piece, then close the outline. The area outside becomes transparent.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if drawing.count >= 3 {
                            Button("Close Outline") { finishOutline() }
                        }
                        Button("Clear Outline") { outline = nil; drawing = [] }
                    } else {
                        slider("Left", value: $region.x, range: 0...max(0, 1 - region.width))
                        slider("Top", value: $region.y, range: 0...max(0, 1 - region.height))
                        slider("Width", value: $region.width, range: 0.1...max(0.1, 1 - region.x))
                        slider("Height", value: $region.height, range: 0.1...max(0.1, 1 - region.y))
                        Button("Use Full Image") {
                            region = NormalizedImageRegion(x: 0, y: 0, width: 1, height: 1)
                        }
                    }
                }
            }
            .navigationTitle("Adjust Image Region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isDrawingOutline ? "Use Outline" : "Use Region") {
                        onSave(region, isDrawingOutline ? outline : nil)
                        dismiss()
                    }
                    .disabled(!region.isValid || (isDrawingOutline && outline == nil))
                }
            }
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            Text("\(title): \(Int(value.wrappedValue * 100))%")
            Slider(value: value, in: range)
        }
    }

    private func finishOutline() {
        defer { drawing = [] }
        guard drawing.count >= 3 else { return }
        let xs = drawing.map(\.x), ys = drawing.map(\.y)
        let left = xs.min()!, top = ys.min()!
        let candidate = NormalizedImageRegion(x: left, y: top,
            width: xs.max()! - left, height: ys.max()! - top)
        guard candidate.isValid, candidate.width >= 0.01, candidate.height >= 0.01 else { return }
        outline = drawing
        region = candidate
    }
}
