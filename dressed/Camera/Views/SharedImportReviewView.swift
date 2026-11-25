import SwiftUI
import UIKit

// Share-to-Dressed review. Two steps, both from the Figma frames:
// 1. One detected piece at a time over the source photo (777:6352 browsing, 1012:282 selected).
// 2. A summary of the accepted pieces with the two import actions (1253:449).
struct SharedImportReviewView: View {
    let image: ReviewImage
    let ownerId: String
    @ObservedObject var closet: PrototypeClosetStore
    let recognizer: any GarmentRecognitionService
    let onLater: () -> Void
    let onDiscard: () -> Void
    let onSaved: () -> Void

    @StateObject private var outfits: PrototypeOutfitStore
    @State private var draft: ImportDraft?
    @State private var isProcessing = false
    @State private var isSaving = false
    @State private var detectionTask: Task<Void, Never>?
    @State private var detectionID = UUID()
    @State private var errorMessage: String?
    @State private var cropCandidateID: String?
    @State private var detailsCandidateID: String?
    @State private var chosenCandidateID: String?
    @State private var confirmsDiscard = false

    init(image: ReviewImage, ownerId: String, closet: PrototypeClosetStore,
         recognizer: any GarmentRecognitionService = OnDeviceImportRecognitionService(),
         onLater: @escaping () -> Void, onDiscard: @escaping () -> Void,
         onSaved: @escaping () -> Void) {
        self.image = image
        self.ownerId = ownerId
        self.closet = closet
        self.recognizer = recognizer
        self.onLater = onLater
        self.onDiscard = onDiscard
        self.onSaved = onSaved
        _outfits = StateObject(wrappedValue: PrototypeOutfitStore(ownerId: ownerId))
    }

    private var reviewedIDs: Set<String> { Set(draft?.reviewedCandidateIDs ?? []) }
    private var reviewedCount: Int {
        draft?.candidates.filter { reviewedIDs.contains($0.id) }.count ?? 0
    }
    private var selectedCandidates: [ImportCandidate] { draft?.candidates.filter(\.selected) ?? [] }
    private var currentCandidate: ImportCandidate? {
        guard let draft, draft.hasFinishedPieceReview != true else { return nil }
        return draft.candidates.first { !reviewedIDs.contains($0.id) }
    }
    private var outfitName: String { draft?.outfitName ?? "Shared outfit" }

    private func canSave(_ mode: ImportSaveMode) -> Bool {
        guard draft != nil else { return false }
        return !isSaving && !isProcessing && !selectedCandidates.isEmpty
            && selectedCandidates.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && (mode == .individualPieces || !outfitName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            DSColor.background.ignoresSafeArea()
            Group {
                if let candidate = currentCandidate {
                    pieceStep(candidate)
                } else if let draft {
                    if isProcessing && draft.candidates.isEmpty {
                        processingStep
                    } else {
                        summaryStep(draft)
                    }
                } else if let errorMessage {
                    VStack(spacing: DSSpacing.md) {
                        Text(errorMessage).font(DSFont.body).foregroundStyle(DSColor.textMuted)
                        Button("Retry", action: loadDraft).buttonStyle(.ds(.secondary))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .disabled(isSaving)
            closeMenu
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
        .sheet(isPresented: Binding(
            get: { detailsCandidateID != nil },
            set: { if !$0 { detailsCandidateID = nil } }
        )) {
            if let id = detailsCandidateID { detailsSheet(id: id) }
        }
        .interactiveDismissDisabled(isSaving)
        .task {
            if draft == nil { loadDraft() }
            else if draft?.status == .processing { processImage() }
        }
        .onDisappear {
            detectionTask?.cancel()
            isProcessing = false
        }
    }

    // MARK: - Step 1: one piece at a time

    private func pieceStep(_ candidate: ImportCandidate) -> some View {
        let isChosen = chosenCandidateID == candidate.id
        let total = draft?.candidates.count ?? 0
        return VStack(spacing: DSSpacing.sm) {
            sourcePhoto(candidate: candidate, isChosen: isChosen,
                        badge: "\(reviewedCount + 1) of \(total)")
            Button {
                chosenCandidateID = isChosen ? nil : candidate.id
            } label: {
                DSCandidateRow(title: candidate.name.isEmpty ? "Add a name" : candidate.name,
                               subtitle: candidate.category.rawValue.capitalized,
                               isSelected: isChosen) {
                    candidateImage(candidate).resizable().scaledToFit()
                }
            }
            .buttonStyle(.dsPress)
            .accessibilityIdentifier("sharedImport.option")
            .accessibilityAddTraits(isChosen ? .isSelected : [])
            if isChosen {
                Button("Edit name and category") { detailsCandidateID = candidate.id }
                    .buttonStyle(.ds(.text))
                    .accessibilityIdentifier("sharedImport.editDetails")
            }
            Button { cropCandidateID = candidate.id } label: {
                HStack(spacing: DSSpacing.sm) {
                    DSIcon("TablerSearch", size: 16)
                    Text("None of these? Find it yourself.").font(DSFont.search)
                }
                .foregroundStyle(DSColor.textMuted)
                .frame(maxWidth: .infinity, minHeight: 43)
                .background(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous).fill(DSColor.background))
                .dsShadow(.card)
            }
            .buttonStyle(.dsPress)
            .accessibilityIdentifier("sharedImport.adjustRegion")
            if let errorMessage {
                Text(errorMessage).font(DSFont.search).foregroundStyle(.red)
            }
            Spacer(minLength: 0)
            pieceFooter(candidate, isChosen: isChosen)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.bottom, DSSpacing.sm)
        .background(DSColor.raised)
        .onChange(of: candidate.id) { _, _ in chosenCandidateID = nil }
    }

    private func pieceFooter(_ candidate: ImportCandidate, isChosen: Bool) -> some View {
        HStack(spacing: DSSpacing.xs) {
            Button("Back") { mutateDraft { SharedImportReviewState.undoLast(in: &$0) } }
                .buttonStyle(.ds(.secondary))
                .frame(width: 81)
                .disabled(reviewedCount == 0)
                .accessibilityIdentifier("sharedImport.back")
            ForEach(selectedCandidates.filter { reviewedIDs.contains($0.id) }) { accepted in
                DSThumbnailSlot { candidateImage(accepted).resizable().scaledToFit() }
            }
            Spacer(minLength: 0)
            if isChosen {
                Button("Next") { review(candidate, selected: true) }
                    .buttonStyle(.ds(.primary))
                    .frame(width: 81)
                    .disabled(candidate.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("sharedImport.approve")
            } else {
                Button("Skip") { review(candidate, selected: false) }
                    .buttonStyle(.ds(.secondary))
                    .frame(width: 81)
                    .accessibilityIdentifier("sharedImport.skip")
            }
        }
    }

    private var processingStep: some View {
        VStack(spacing: DSSpacing.sm) {
            sourcePhoto(candidate: nil, isChosen: false, badge: nil)
            ProgressView("Finding possible pieces…")
                .font(DSFont.body).foregroundStyle(DSColor.textMuted)
                .padding(.top, DSSpacing.lg)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DSSpacing.sm)
        .background(DSColor.raised)
    }

    /// The source photo with the detected region framed: white while browsing, purple once chosen.
    private func sourcePhoto(candidate: ImportCandidate?, isChosen: Bool, badge: String?) -> some View {
        let uiImage = UIImage(data: image.data)
        return DSColor.textMuted
            .frame(height: 330)
            .overlay {
                GeometryReader { proxy in
                    if let uiImage {
                        // Fill the width like the mockup, scrolled so the framed piece stays in view.
                        let scale = max(proxy.size.width / uiImage.size.width, proxy.size.height / uiImage.size.height)
                        let display = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                        let focusY = candidate.flatMap(\.region).map {
                            ($0.y + $0.height / 2) * display.height
                        } ?? display.height / 2
                        let originY = min(0, max(proxy.size.height - display.height, proxy.size.height / 2 - focusY))
                        let origin = CGPoint(x: (proxy.size.width - display.width) / 2, y: originY)
                        Image(uiImage: uiImage).resizable()
                            .frame(width: display.width, height: display.height)
                            .position(x: origin.x + display.width / 2, y: origin.y + display.height / 2)
                            .accessibilityLabel("Shared image to review")
                        if let region = candidate?.region {
                            let frame = CGRect(x: origin.x + region.x * display.width,
                                               y: origin.y + region.y * display.height,
                                               width: region.width * display.width,
                                               height: region.height * display.height)
                            DSCropFrame(color: isChosen ? DSColor.brand : .white)
                                .frame(width: frame.width, height: frame.height)
                                .position(x: frame.midX, y: frame.midY)
                            if let badge {
                                DSBadge(text: badge, kind: isChosen ? .counterSelected : .counter)
                                    .position(x: frame.midX, y: frame.maxY)
                            }
                        } else if let badge {
                            DSBadge(text: badge, kind: .counter)
                                .position(x: proxy.size.width / 2, y: proxy.size.height - 24)
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
    }

    // MARK: - Step 2: summary and import

    private func summaryStep(_ draft: ImportDraft) -> some View {
        let selected = selectedCandidates
        return ScrollView {
            VStack(spacing: DSSpacing.md) {
                if isProcessing {
                    ProgressView("Finding possible pieces…")
                        .font(DSFont.body).foregroundStyle(DSColor.textMuted)
                }
                DSOutfitCollage(count: min(4, selected.count), cornerRadius: DSRadius.md) { index in
                    candidateImage(selected[index]).resizable().scaledToFit()
                }
                .accessibilityIdentifier("sharedImport.collage")
                if selected.isEmpty {
                    Text(draft.candidates.isEmpty
                         ? "No pieces found. Use Find More to add one yourself, or try recognition again."
                         : "No pieces selected. Use Back to review them again or Find More to add one.")
                        .font(DSFont.body).foregroundStyle(DSColor.textMuted)
                        .multilineTextAlignment(.center)
                    if draft.candidates.isEmpty {
                        Button("Try Recognition Again", action: processImage)
                            .buttonStyle(.ds(.secondary))
                            .disabled(isProcessing)
                    }
                } else {
                    VStack(spacing: DSSpacing.xs) {
                        ForEach(selected) { candidate in
                            DSItemRow(title: candidate.name.isEmpty ? "Add a name" : candidate.name, trailing: {
                                DSMoreMenu(accessibilityLabel: "More options for \(candidate.name)") {
                                    Button("Edit name and category") { detailsCandidateID = candidate.id }
                                    Button("Adjust image region") { cropCandidateID = candidate.id }
                                    Button("Remove", role: .destructive) { remove(candidate) }
                                }
                            }) { candidateImage(candidate).resizable().scaledToFit() }
                        }
                    }
                    DSLabeledField(label: "Outfit Name", prompt: "Shared outfit", text: Binding(
                        get: { self.draft?.outfitName ?? "Shared outfit" },
                        set: { name in mutateDraft { $0.outfitName = name } }
                    ))
                    .accessibilityIdentifier("sharedImport.outfitName")
                }
                if let errorMessage {
                    Text(errorMessage).font(DSFont.search).foregroundStyle(.red)
                }
                VStack(spacing: DSSpacing.xs) {
                    Button { confirm(.outfit) } label: {
                        Text(isSaving ? "Saving…" : "Import as Outfit").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.ds(.primary))
                    .disabled(!canSave(.outfit))
                    .accessibilityIdentifier("sharedImport.confirm")
                    Button { confirm(.individualPieces) } label: {
                        Text("Import as Individual Pieces").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.ds(.secondary))
                    .disabled(!canSave(.individualPieces))
                    .accessibilityIdentifier("sharedImport.confirmIndividual")
                    Button { addManualCandidate() } label: {
                        Text("Find More").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.ds(.text))
                    .disabled(isProcessing)
                    .accessibilityIdentifier("sharedImport.findMore")
                }
                .padding(.top, DSSpacing.sm)
            }
            .padding(.horizontal, DSSpacing.sm)
            .padding(.top, 56)
            .padding(.bottom, DSSpacing.lg)
        }
        .background(DSColor.background)
    }

    private var closeMenu: some View {
        Menu {
            Button("Later") { detectionTask?.cancel(); onLater() }
            Button("Discard", role: .destructive) { confirmsDiscard = true }
        } label: {
            DSIcon("TablerX", size: 24)
                .foregroundStyle(DSColor.textPrimary)
                .frame(width: 43, height: 43)
                .background(Circle().fill(DSColor.glass))
        }
        .disabled(isSaving)
        .padding(DSSpacing.md)
        .accessibilityLabel("Close")
        .accessibilityIdentifier("sharedImport.close")
    }

    private func detailsSheet(id: String) -> some View {
        NavigationStack {
            Form {
                TextField("Piece name", text: Binding(
                    get: { draft?.candidates.first(where: { $0.id == id })?.name ?? "" },
                    set: { name in mutateCandidate(id: id) { $0.name = name } }
                ))
                Picker("Category", selection: Binding(
                    get: { draft?.candidates.first(where: { $0.id == id })?.category ?? .other },
                    set: { category in mutateCandidate(id: id) { $0.category = category } }
                )) {
                    ForEach(ClothingCategory.allCases, id: \.self) { category in
                        Text(category.rawValue.capitalized).tag(category)
                    }
                }
                if let source = draft?.candidates.first(where: { $0.id == id })?.suggestionSource {
                    Text(source).font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Piece details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { detailsCandidateID = nil } }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Draft changes

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
            if loaded.status == .saving {
                loaded.status = loaded.candidates.isEmpty ? .received : .review
                try SharedImportDraftStore.save(loaded)
            }
            draft = loaded
            errorMessage = nil
            if SharedImportDraftStore.shouldRecognize(loaded) {
                processImage()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func processImage() {
        guard !isProcessing, draft != nil,
              mutateDraft({ $0.status = .processing }) else { return }
        isProcessing = true
        detectionTask?.cancel()
        let attempt = UUID()
        detectionID = attempt
        detectionTask = Task {
            defer { if detectionID == attempt { isProcessing = false } }
            do {
                let found = try await recognizer.detect(imageData: image.data, importID: image.id)
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
                errorMessage = "Could not recognize pieces. Use Find More to add them yourself, or try again."
            }
        }
    }

    /// Adds a piece the recognizer missed. It is already reviewed and selected so it shows in the summary;
    /// the region editor opens right away and the name is filled in from the piece's row menu.
    private func addManualCandidate() {
        guard draft != nil else { return }
        let candidate = ImportCandidate(id: UUID().uuidString, name: "", category: .other,
                                        destination: .closet, temporaryCutoutPath: nil,
                                        region: nil, suggestionSource: nil, selected: true,
                                        tags: [], suggestedTags: [])
        if mutateDraft({
            $0.candidates.append(candidate)
            $0.reviewedCandidateIDs = ($0.reviewedCandidateIDs ?? []) + [candidate.id]
            $0.hasFinishedPieceReview = true
            $0.status = isProcessing ? .processing : .review
        }) {
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

    private func candidateImage(_ candidate: ImportCandidate) -> Image {
        if let data = try? SharedImportDraftStore.imageData(for: candidate, in: image.data),
           let preview = UIImage(data: data) {
            return Image(uiImage: preview)
        }
        return Image("TablerPhoto")
    }

    private func confirm(_ mode: ImportSaveMode) {
        guard let current = draft, canSave(mode) else { return }
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
