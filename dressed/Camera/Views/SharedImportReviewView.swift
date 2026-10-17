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
    @State private var outfitName = "Shared outfit"
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let original = UIImage(data: image.data) {
                        Image(uiImage: original)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 260)
                            .accessibilityLabel("Shared image to review")
                    }
                    Text("Private shared image. Nothing enters your closet until you confirm.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if isProcessing {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Finding possible pieces…")
                        }
                    }
                }

                if let draft {
                    Section {
                        Text(draft.candidates.isEmpty
                             ? "No pieces found. Add one manually or try again."
                             : "Check each suggested piece and its cutout. Select only what you want to save.")
                            .foregroundStyle(.secondary)
                        Button("Add Piece Manually", systemImage: "plus", action: addManualCandidate)
                        if !isProcessing {
                            Button("Find Pieces Again", systemImage: "arrow.clockwise", action: processImage)
                        }
                    } header: {
                        Text("Pieces in Image")
                    }

                    ForEach(draft.candidates) { candidate in
                        Section {
                            ImportCandidateRow(
                                name: candidate.name,
                                thumbnail: candidateImage(candidate),
                                isSelected: selectedBinding(for: candidate.id)
                            )
                            TextField("Piece name", text: nameBinding(for: candidate.id))
                            Picker("Category", selection: categoryBinding(for: candidate.id)) {
                                ForEach(ClothingCategory.allCases, id: \.self) { category in
                                    Text(category.rawValue.capitalized).tag(category)
                                }
                            }
                            HStack {
                                Button("Adjust Image Region") { cropCandidateID = candidate.id }
                                Spacer()
                                Button("Remove", role: .destructive) {
                                    SharedImportDraftStore.removeAutomaticCutouts(for: [candidate])
                                    mutateDraft { $0.candidates.removeAll { $0.id == candidate.id } }
                                }
                            }
                            if let source = candidate.suggestionSource {
                                Text(source).font(.caption).foregroundStyle(.secondary)
                            }
                        } header: {
                            Text("Piece \((draft.candidates.firstIndex { $0.id == candidate.id } ?? 0) + 1)")
                        }
                    }

                    Section("Save Reviewed Selection") {
                        TextField("Outfit name", text: $outfitName)
                        Text("\(selectedCount) of \(draft.candidates.count) pieces selected")
                            .foregroundStyle(.secondary)
                        Button(isSaving ? "Saving…" : "Save Pieces and Outfit", action: confirm)
                            .disabled(isSaving || isProcessing || selectedCount == 0
                                      || outfitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Review Shared Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") {
                        detectionTask?.cancel()
                        onLater()
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Discard", role: .destructive) { confirmsDiscard = true }
                        .disabled(isSaving)
                }
            }
            .confirmationDialog("Discard this shared image?", isPresented: $confirmsDiscard) {
                Button("Discard Image", role: .destructive) {
                    detectionTask?.cancel()
                    onDiscard()
                }
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
                        SharedImportDraftStore.removeAutomaticCutouts(for: [candidate])
                        mutateCandidate(id: id) {
                            $0.region = region
                            $0.outline = outline
                            $0.temporaryCutoutPath = nil
                        }
                        cropCandidateID = nil
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .task { loadDraft() }
            .onDisappear { detectionTask?.cancel() }
        }
    }

    private func loadDraft() {
        guard draft == nil else { return }
        do {
            var loaded = try SharedImportDraftStore.loadOrCreate(image: image, ownerId: ownerId)
            if loaded.status == .saving || loaded.status == .processing {
                loaded.status = loaded.candidates.isEmpty ? .received : .review
                try SharedImportDraftStore.save(loaded)
            }
            draft = loaded
            if loaded.status == .received || (loaded.status == .review && loaded.candidates.isEmpty) {
                processImage()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func processImage() {
        guard var current = draft, !isProcessing else { return }
        current.status = .processing
        do { try SharedImportDraftStore.save(current) } catch {
            errorMessage = error.localizedDescription
            return
        }
        draft = current
        isProcessing = true
        detectionTask?.cancel()
        detectionTask = Task {
            do {
                let found = try await AutomaticImportSuggestions.detect(imageData: image.data, importID: image.id)
                guard !Task.isCancelled else {
                    SharedImportDraftStore.removeAutomaticCutouts(for: found)
                    return
                }
                mutateDraft { value in
                    // A retry retains manual pieces and prior user edits.
                    let existing = Dictionary(uniqueKeysWithValues: value.candidates.map { ($0.id, $0) })
                    let manual = value.candidates.filter { $0.suggestionSource == nil }
                    value.candidates = found.map { existing[$0.id] ?? $0 } + manual
                    value.status = .review
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                mutateDraft { $0.status = .review }
                errorMessage = "Automatic suggestions are unavailable. Add pieces manually or try again."
            }
            isProcessing = false
        }
    }

    private func addManualCandidate() {
        guard let draft else { return }
        var ordinal = 0
        var id = SharedImportDraftStore.stableID(importID: draft.id, part: "manual-\(ordinal)")
        while draft.candidates.contains(where: { $0.id == id }) {
            ordinal += 1
            id = SharedImportDraftStore.stableID(importID: draft.id, part: "manual-\(ordinal)")
        }
        let candidate = ImportCandidate(id: id, name: "", category: .other,
                                        destination: .closet, temporaryCutoutPath: nil,
                                        region: nil, suggestionSource: nil, selected: false,
                                        tags: [], suggestedTags: [])
        mutateDraft { $0.candidates.append(candidate); $0.status = .review }
        cropCandidateID = id
    }

    private func mutateDraft(_ change: (inout ImportDraft) -> Void) {
        guard var updated = draft else { return }
        change(&updated)
        do {
            try SharedImportDraftStore.save(updated)
            draft = updated
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func mutateCandidate(id: String, _ change: (inout ImportCandidate) -> Void) {
        mutateDraft { value in
            guard let index = value.candidates.firstIndex(where: { $0.id == id }) else { return }
            change(&value.candidates[index])
        }
    }

    private func selectedBinding(for id: String) -> Binding<Bool> {
        Binding(get: { draft?.candidates.first(where: { $0.id == id })?.selected ?? false },
                set: { selection in mutateCandidate(id: id) { $0.selected = selection } })
    }

    private func nameBinding(for id: String) -> Binding<String> {
        Binding(get: { draft?.candidates.first(where: { $0.id == id })?.name ?? "" },
                set: { name in mutateCandidate(id: id) { $0.name = name } })
    }

    private func categoryBinding(for id: String) -> Binding<ClothingCategory> {
        Binding(get: { draft?.candidates.first(where: { $0.id == id })?.category ?? .other },
                set: { category in mutateCandidate(id: id) { $0.category = category } })
    }

    private func candidateImage(_ candidate: ImportCandidate) -> Image {
        if let data = try? SharedImportDraftStore.imageData(for: candidate, in: image.data),
           let preview = UIImage(data: data) {
            return Image(uiImage: preview)
        }
        return Image(systemName: "photo")
    }

    private func confirm() {
        guard let current = draft, !isSaving else { return }
        isSaving = true
        do {
            let coordinator = SharedImportSaveCoordinator(closet: closet, outfits: outfits)
            _ = try coordinator.confirm(draft: current, imageData: image.data, outfitName: outfitName)
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
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
