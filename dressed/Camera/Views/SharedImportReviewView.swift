import SwiftUI
import UIKit

// Piece review for shared images, camera captures and single uploads. Two steps, both from the Figma frames:
// 1. One detected piece at a time over the source photo (777:6352 browsing, 1012:282 selected),
//    with up to three visually similar catalog products to choose from.
// 2. A summary of the accepted pieces with the two import actions (1253:449).
struct SharedImportReviewView: View {
    let image: ReviewImage
    let ownerId: String
    @ObservedObject var closet: PrototypeClosetStore
    let recognizer: any GarmentRecognitionService
    let matcher: any ProductMatching
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
    @State private var searchCandidateID: String?
    /// The option picked for the current piece: a product match ID, or `ownPhotoOption`.
    @State private var chosenOption: String?
    @State private var matches: [String: [ProductMatch]] = [:]
    @State private var matchLoadingIDs: Set<String> = []
    private let ownPhotoOption = "own-photo"

    init(image: ReviewImage, ownerId: String, closet: PrototypeClosetStore,
         recognizer: any GarmentRecognitionService = OnDeviceImportRecognitionService(),
         matcher: (any ProductMatching)? = nil,
         onDiscard: @escaping () -> Void,
         onSaved: @escaping () -> Void) {
        self.image = image
        self.ownerId = ownerId
        self.closet = closet
        self.recognizer = recognizer
        self.matcher = matcher ?? CatalogVisualMatcher.shared
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
        ZStack(alignment: .topLeading) {
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
            closeButton
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
            get: { searchCandidateID != nil },
            set: { if !$0 { searchCandidateID = nil } }
        )) {
            if let id = searchCandidateID {
                ProductSearchSheet(matcher: matcher, onClose: { searchCandidateID = nil }) { match in
                    matches[id] = [match] + (matches[id] ?? []).filter { $0.id != match.id }.prefix(2)
                    chosenOption = match.id
                    searchCandidateID = nil
                }
            }
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

    // Sizes from 1012:282 (402 x 874): a 385 pt square photo, 82 pt rows 4 pt apart, a 56 pt
    // search row and a 50 pt footer. The photo gives up height first on smaller phones.
    private func pieceStep(_ candidate: ImportCandidate) -> some View {
        let total = draft?.candidates.count ?? 0
        let found = matches[candidate.id] ?? []
        let isLoadingMatches = matchLoadingIDs.contains(candidate.id)
        return VStack(spacing: 0) {
            sourcePhoto(candidate: candidate, isChosen: chosenOption != nil,
                        badge: "\(reviewedCount + 1) of \(total)")
            VStack(spacing: DSSpacing.xs) {
                if isLoadingMatches && found.isEmpty {
                    ForEach(0..<3, id: \.self) { _ in
                        DSCandidateRow(title: "Finding similar pieces…", subtitle: " ") { ProgressView() }
                    }
                    .accessibilityIdentifier("sharedImport.matchesLoading")
                }
                ForEach(found) { match in
                    let isChosen = chosenOption == match.id
                    Button { chosenOption = isChosen ? nil : match.id } label: {
                        DSCandidateRow(title: match.product.title,
                                       subtitle: match.product.brand ?? match.product.sourceName,
                                       isSelected: isChosen) {
                            if let image = match.image {
                                Image(uiImage: image).resizable().scaledToFit()
                            } else {
                                DSIcon("TablerPhoto", size: 20).foregroundStyle(DSColor.textPlaceholder)
                            }
                        }
                    }
                    .buttonStyle(.dsPress)
                    .accessibilityIdentifier("sharedImport.match")
                    .accessibilityAddTraits(isChosen ? .isSelected : [])
                }
                // With no catalog match, the piece can still be kept using its own photo.
                if !isLoadingMatches && found.isEmpty {
                    let isChosen = chosenOption == ownPhotoOption
                    Button { chosenOption = isChosen ? nil : ownPhotoOption } label: {
                        DSCandidateRow(title: candidate.name, subtitle: "Your photo",
                                       isSelected: isChosen) {
                            candidateImage(candidate).resizable().scaledToFit()
                        }
                    }
                    .buttonStyle(.dsPress)
                    .accessibilityIdentifier("sharedImport.option")
                    .accessibilityAddTraits(isChosen ? .isSelected : [])
                }
                Button { searchCandidateID = candidate.id } label: {
                    HStack(spacing: DSSpacing.xs) {
                        DSIcon("TablerSearch", size: 18)
                        Text("None of these? Find it yourself.").font(DSFont.bodyEmphasis)
                    }
                    .foregroundStyle(DSColor.textMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous).fill(DSColor.background))
                    .dsShadow(.card)
                }
                .buttonStyle(.dsPress)
                .accessibilityIdentifier("sharedImport.findYourself")
            }
            .padding(.top, DSSpacing.sm)
            Spacer(minLength: DSSpacing.sm)
            if let errorMessage {
                Text(errorMessage).font(DSFont.search).foregroundStyle(.red)
            }
            pieceFooter(candidate)
                .padding(.leading, DSSpacing.xs)
        }
        .padding(.horizontal, 9)
        .padding(.bottom, 11)
        .background(DSColor.background)
        .onChange(of: candidate.id) { _, _ in chosenOption = nil }
        .task(id: candidate.id) { await loadMatches(for: candidate) }
    }

    private func pieceFooter(_ candidate: ImportCandidate) -> some View {
        HStack(spacing: DSSpacing.xs) {
            Button("Back") { mutateDraft { SharedImportReviewState.undoLast(in: &$0) } }
                .buttonStyle(.ds(.secondary, width: 81))
                .disabled(reviewedCount == 0)
                .accessibilityIdentifier("sharedImport.back")
            // Small previews of the pieces accepted so far.
            ScrollView(.horizontal) {
                HStack(spacing: DSSpacing.xs) {
                    ForEach(selectedCandidates.filter { reviewedIDs.contains($0.id) }) { accepted in
                        DSThumbnailSlot { candidateImage(accepted).resizable().scaledToFit() }
                            .accessibilityElement()
                            .accessibilityLabel("Selected: \(accepted.name)")
                            .accessibilityIdentifier("sharedImport.selectedPreview")
                    }
                }
            }
            .scrollIndicators(.hidden)
            if chosenOption != nil {
                Button("Next") { accept(candidate) }
                    .buttonStyle(.ds(.primary, width: 81))
                    .accessibilityIdentifier("sharedImport.approve")
            } else {
                Button("Skip") { review(candidate, selected: false) }
                    .buttonStyle(.ds(.secondary, width: 81))
                    .accessibilityIdentifier("sharedImport.skip")
            }
        }
        .frame(height: 50)
    }

    /// Accepts the piece. A chosen match fills in its name and category; the saved photo stays the person's own crop.
    private func accept(_ candidate: ImportCandidate) {
        if let option = chosenOption,
           let match = matches[candidate.id]?.first(where: { $0.id == option }) {
            guard mutateCandidate(id: candidate.id, {
                $0.name = match.product.title
                if match.product.category != .other { $0.category = match.product.category }
                $0.suggestionSource = "Similar to \(match.product.title) (\(match.product.sourceName))"
            }) else { return }
        }
        review(candidate, selected: true)
    }

    private func loadMatches(for candidate: ImportCandidate) async {
        guard matches[candidate.id] == nil, !matchLoadingIDs.contains(candidate.id),
              let crop = try? SharedImportDraftStore.imageData(for: candidate, in: image.data) else { return }
        matchLoadingIDs.insert(candidate.id)
        defer { matchLoadingIDs.remove(candidate.id) }
        do {
            matches[candidate.id] = try await matcher.matches(for: crop, category: candidate.category)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            // Catalog unavailable: the piece's own photo stays available, so review can continue.
            matches[candidate.id] = []
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
        .padding(.horizontal, 9)
        .background(DSColor.background)
    }

    /// The source photo with the detected region framed: white while browsing, purple once chosen.
    private func sourcePhoto(candidate: ImportCandidate?, isChosen: Bool, badge: String?) -> some View {
        let uiImage = UIImage(data: image.data)
        return DSColor.thumbnail
            .aspectRatio(1, contentMode: .fit) // always square (385 x 385 on a 402 pt screen)
            .overlay {
                GeometryReader { proxy in
                    if let uiImage {
                        // Fill the square like the mockup, scrolled so the framed piece stays in view.
                        // A piece too large for that crop zooms out until its whole frame fits.
                        let region = candidate?.region
                        let fill = max(proxy.size.width / uiImage.size.width, proxy.size.height / uiImage.size.height)
                        let fit = min(proxy.size.width / uiImage.size.width, proxy.size.height / uiImage.size.height)
                        let whole = region.map {
                            min(proxy.size.width * 0.86 / ($0.width * uiImage.size.width),
                                proxy.size.height * 0.82 / ($0.height * uiImage.size.height))
                        } ?? fill
                        let scale = max(fit, min(fill, whole))
                        let display = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                        let focusY = region.map { ($0.y + $0.height / 2) * display.height } ?? display.height / 2
                        let focusX = region.map { ($0.x + $0.width / 2) * display.width } ?? display.width / 2
                        let origin = CGPoint(x: Self.offset(view: proxy.size.width, image: display.width, focus: focusX),
                                             y: Self.offset(view: proxy.size.height, image: display.height, focus: focusY))
                        let photo = Image(uiImage: uiImage).resizable()
                            .frame(width: display.width, height: display.height)
                            .position(x: origin.x + display.width / 2, y: origin.y + display.height / 2)
                        // Visible part of the detected region.
                        let frame = region.map {
                            CGRect(x: origin.x + $0.x * display.width, y: origin.y + $0.y * display.height,
                                   width: $0.width * display.width, height: $0.height * display.height)
                                .intersection(CGRect(origin: .zero, size: proxy.size).insetBy(dx: 6, dy: 6))
                        }
                        // The photo is faded outside the framed piece.
                        photo.opacity(frame == nil ? 1 : 0.6)
                            .accessibilityLabel("Shared image to review")
                        if let frame {
                            photo.mask {
                                RoundedRectangle(cornerRadius: DSRadius.crop, style: .continuous)
                                    .frame(width: frame.width, height: frame.height)
                                    .position(x: frame.midX, y: frame.midY)
                            }
                            .accessibilityHidden(true)
                            DSCropFrame(color: isChosen ? DSColor.brand : .white)
                                .frame(width: frame.width, height: frame.height)
                                .position(x: frame.midX, y: frame.midY)
                        }
                        if let badge {
                            // 5 pt under the frame, kept inside the photo.
                            let below = (frame?.maxY ?? proxy.size.height) + 19
                            DSBadge(text: badge, kind: isChosen ? .counterSelected : .counter)
                                .position(x: frame?.midX ?? proxy.size.width / 2,
                                          y: min(below, proxy.size.height - 19))
                        }
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
    }

    /// Centers on the piece without leaving a gap; centers the photo on an axis it does not fill.
    private static func offset(view: CGFloat, image: CGFloat, focus: CGFloat) -> CGFloat {
        image <= view ? (view - image) / 2 : min(0, max(view - image, view / 2 - focus))
    }

    // MARK: - Step 2: summary and import

    // Sizes from 1253:449: a 362 pt collage with 7 pt gaps, 64 pt rows 4 pt apart and
    // the three actions pinned 14 pt above the bottom edge.
    private func summaryStep(_ draft: ImportDraft) -> some View {
        let selected = selectedCandidates
        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    if isProcessing {
                        ProgressView("Finding possible pieces…")
                            .font(DSFont.body).foregroundStyle(DSColor.textMuted)
                    }
                    DSOutfitCollage(count: min(4, selected.count), cornerRadius: DSRadius.md, gap: 7) { index in
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
                                DSItemRow(title: candidate.name, trailing: {
                                    DSMoreMenu(accessibilityLabel: "More options for \(candidate.name)") {
                                        Button("Remove", role: .destructive) { remove(candidate) }
                                    }
                                }) { candidateImage(candidate).resizable().scaledToFit() }
                            }
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage).font(DSFont.search).foregroundStyle(.red)
                    }
                }
            }
            .scrollIndicators(.hidden)
            // Keeps the close control above the collage instead of over a piece.
            .padding(.top, 50 + DSSpacing.md)
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
            .padding(.bottom, 14)
        }
        .padding(.horizontal, DSSpacing.lg)
        .ignoresSafeArea(.container, edges: .bottom)
        .background(DSColor.background)
    }

    /// Closing discards the photo and its draft at once.
    private var closeButton: some View {
        DSCloseButton {
            detectionTask?.cancel()
            onDiscard()
        }
        .disabled(isSaving)
        // 9 pt from the left edge, over the photo's top-left corner as on the camera.
        .padding(.leading, 9)
        .padding(.top, DSSpacing.sm)
        .accessibilityIdentifier("sharedImport.close")
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
                // The framed whole-photo fallback only stands in when there is nothing else to review:
                // no detected pieces and no pieces the user already added.
                let hasOtherPieces = !(draft?.candidates.isEmpty ?? true)
                    || found.contains { $0.suggestionSource != "Review this photo" }
                var usable = found.filter {
                    !removed.contains($0.id) && !(hasOtherPieces && $0.suggestionSource == "Review this photo")
                }
                // Frame the whole-photo piece around the foreground subject (else the whole photo), so every
                // piece has a box in review. Done here, not in recognition, so speed tests measure recognition only.
                if usable.contains(where: { $0.region == nil }) {
                    let data = image.data
                    let frame = await Task.detached(priority: .userInitiated) {
                        OnDeviceGarmentRegions.foregroundBounds(imageData: data)
                    }.value ?? NormalizedImageRegion(x: 0, y: 0, width: 1, height: 1)
                    guard !Task.isCancelled else {
                        SharedImportDraftStore.removeAutomaticCutouts(for: found)
                        return
                    }
                    for index in usable.indices where usable[index].region == nil {
                        usable[index].region = frame
                    }
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
    /// the region editor opens right away.
    private func addManualCandidate() {
        guard draft != nil else { return }
        let candidate = ImportCandidate(id: UUID().uuidString, name: "Piece", category: .other,
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

/// "None of these? Find it yourself.": search the catalog and pick a product for the piece.
private struct ProductSearchSheet: View {
    let matcher: any ProductMatching
    let onClose: () -> Void
    let onPick: (ProductMatch) -> Void
    @State private var query = ""
    @State private var results: [ProductMatch]?
    @State private var failed = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DSSpacing.md) {
                DSCloseButton(accessibilityLabel: "Close search", action: onClose)
                    .accessibilityIdentifier("sharedImport.searchClose")
                Text("Find it yourself").font(DSFont.bodyEmphasis).foregroundStyle(DSColor.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.top, DSSpacing.md)
            ScrollView {
                LazyVStack(spacing: DSSpacing.xs) {
                    if failed {
                        Text("The catalog is unavailable. Try again later.")
                            .font(DSFont.body).foregroundStyle(DSColor.textMuted)
                    } else if results == nil {
                        ProgressView()
                    } else if results?.isEmpty == true {
                        Text("No products found.").font(DSFont.body).foregroundStyle(DSColor.textMuted)
                    }
                    ForEach(results ?? []) { match in
                        Button { onPick(match) } label: {
                            DSCandidateRow(title: match.product.title,
                                           subtitle: match.product.brand ?? match.product.sourceName) {
                                if let image = match.image {
                                    Image(uiImage: image).resizable().scaledToFit()
                                } else {
                                    DSIcon("TablerPhoto", size: 20).foregroundStyle(DSColor.textPlaceholder)
                                }
                            }
                        }
                        .buttonStyle(.dsPress)
                        .accessibilityIdentifier("sharedImport.searchResult")
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, DSSpacing.md)
            }
            .scrollDismissesKeyboard(.immediately)
            DSSearchField(prompt: "Search products", query: $query)
                .focused($searchFocused)
                .accessibilityIdentifier("sharedImport.search")
                .padding(.horizontal, 9)
                .padding(.bottom, DSSpacing.sm)
        }
        .background(DSColor.background)
        .onAppear { searchFocused = true }
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            do {
                results = try await matcher.search(query)
                failed = false
            } catch {
                guard !Task.isCancelled else { return }
                failed = true
            }
        }
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
