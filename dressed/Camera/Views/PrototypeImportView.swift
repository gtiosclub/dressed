import PhotosUI
import SwiftUI
import UIKit

struct PrototypeImportView: View {
    @ObservedObject var closet: PrototypeClosetStore
    let ownerId: String
    /// Leaves the camera and returns to the previous tab.
    let onClose: () -> Void
    /// Set while a shared item is deferred; shows a Review Share button over the camera.
    var onReviewShare: (() -> Void)?
    /// Presents the piece review for a queued camera capture or single upload.
    /// Without it, the older single-photo form below is used.
    var onReviewImage: ((ReviewImage) -> Void)?

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoLoadingTask: Task<Void, Never>?
    @State private var review: ReviewImage?
    @State private var showsUploadChoices = false
    @State private var showsPhotoPicker = false
    @State private var showsLinkPrompt = false
    @State private var isLoadingSelectedPhoto = false
    @State private var importError: String?
    @State private var productURLText = ""
    @State private var productLink: ReviewProductLink?

    var body: some View {
        CameraCaptureView(
            onClose: onClose,
            onUpload: { showsUploadChoices = true },
            onPhoto: { data in
                startReview(ReviewImage(id: UUID().uuidString, data: data, source: "Camera", isShared: false))
            },
            onReviewShare: onReviewShare
        )
        .overlay {
            if isLoadingSelectedPhoto { ProgressView("Loading photo…").tint(.white).foregroundStyle(.white) }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Upload", isPresented: $showsUploadChoices) {
            Button("Photo") { showsPhotoPicker = true }
            Button("Product Link") { showsLinkPrompt = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showsPhotoPicker, selection: $selectedPhoto, matching: .images)
        .alert("Add a product link", isPresented: $showsLinkPrompt) {
            TextField("https://store.example/product", text: $productURLText)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("productURLField")
            Button("Review Product Link") {
                guard let url = ProductLinkValidation.normalize(productURLText) else {
                    importError = ProductLinkError.invalidURL.localizedDescription
                    return
                }
                productLink = ReviewProductLink(id: UUID().uuidString, url: url, isShared: false)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Product links go to Wishlist after review; they do not become owned closet pieces.")
        }
        .onChange(of: selectedPhoto) { _, photo in
            photoLoadingTask?.cancel()
            photoLoadingTask = Task { await load(photo) }
        }
        .sheet(item: $review) { image in
            ImportReviewView(
                image: image,
                closet: closet,
                onCancel: { review = nil },
                onSaved: { review = nil },
                onAnotherPhoto: { newImage in review = newImage }
            )
        }
        .sheet(item: $productLink) { link in
            ProductLinkReviewView(link: link, ownerId: ownerId,
                                  onLater: { productLink = nil },
                                  onSaved: {
                                      productLink = nil
                                      productURLText = ""
                                  })
        }
        .alert("Could not import image", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Please try again.")
        }
    }

    /// Camera captures and single uploads use the same piece review as shared images.
    private func startReview(_ image: ReviewImage) {
        guard let onReviewImage else { review = image; return }
        do {
            onReviewImage(try SharedImageInbox.enqueue(imageData: image.data, ownerId: ownerId, source: image.source))
        } catch {
            importError = error.localizedDescription
        }
    }

    /// Loads the picked photo, then goes straight to review.
    private func load(_ photo: PhotosPickerItem?) async {
        guard let photo else {
            isLoadingSelectedPhoto = false
            return
        }

        isLoadingSelectedPhoto = true
        let data = try? await photo.loadTransferable(type: Data.self)
        guard !Task.isCancelled else { return }
        isLoadingSelectedPhoto = false
        // Cleared so the same photo can be picked again.
        selectedPhoto = nil

        guard let data, UIImage(data: data) != nil else {
            importError = "The selected photo could not be loaded. Choose it again."
            return
        }
        startReview(ReviewImage(id: ImportPhotoID.make(for: data), data: data,
                                source: "Photo Library", isShared: false))
    }
}

struct ImportReviewView: View {
    let image: ReviewImage
    @ObservedObject var closet: PrototypeClosetStore
    let onCancel: () -> Void
    let onSaved: () -> Void
    // P18 handoff to P17: when the person chooses another photo for a possible
    // missing piece, hand the new image back so review starts again on it.
    var onAnotherPhoto: ((ReviewImage) -> Void)? = nil

    private enum RecognitionState: Equatable {
        case analyzing
        case noMatch
        case failed
        case manual
    }

    enum ImportPreviewMode: String, CaseIterable, Identifiable {
        case avatar3D = "3D Try-On"
        case avatar2D = "Avatar Style"
        case original = "Original Photo"

        var id: String { rawValue }
    }

    @State private var name = ""
    @State private var category: ClothingCategory = .other
    @State private var selectedPreset: GarmentPreset = .tShirt
    @State private var activeFilter: PresetFilterCategory = .all
    @State private var previewMode: ImportPreviewMode = .original
    @State private var hasEditedName = false
    @State private var hasEditedCategory = false
    @State private var recognitionState: RecognitionState = .analyzing
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var candidates: [ImportCandidate] = []
    @State private var possibleMissing: [PossibleMissingPiece] = []
    @State private var isDetectingPieces = false
    @State private var detectionMessage: String?
    @State private var editingCandidateID: String?
    @State private var didStartPieceDetection = false
    @State private var detectionTask: Task<Void, Never>?
    @State private var stylizedResult: GarmentStylizer.StylizedResult?

    private var filteredPresets: [GarmentPreset] {
        if activeFilter == .all {
            return GarmentPreset.allCases
        }
        return GarmentPreset.allCases.filter { $0.filterCategory == activeFilter }
    }
    @State private var detectionID = UUID()
    @State private var additionalPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Preview Section
                Section {
                    previewContent
                        .frame(maxWidth: .infinity)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))

                    Picker("Preview Mode", selection: $previewMode) {
                        ForEach(ImportPreviewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Extracted colors & details info bar
                    if let stylized = stylizedResult {
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color(uiColor: stylized.dominantColor))
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
                                Text("Dominant Color")
                                    .font(.caption2.weight(.medium))
                            }

                            if let accent = stylized.accentColor {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(uiColor: accent))
                                        .frame(width: 18, height: 18)
                                        .overlay(Circle().stroke(Color.black.opacity(0.15), lineWidth: 1))
                                    Text("Accent")
                                        .font(.caption2.weight(.medium))
                                }
                            }

                            Spacer()

                            if stylized.graphicEmblem != nil {
                                Label("Design Extracted", tabler: "TablerSparkles", size: 11)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.purple)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    Text(image.source)
                        .foregroundStyle(.secondary)
                        .font(.caption2)
                }

                Section("Pieces in Photo") {
                    Text("Suggestions appear automatically. Check each cutout and select the pieces you want to save.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(isDetectingPieces ? "Finding pieces…" : "Find Pieces Again", action: detectPieces)
                        .disabled(isDetectingPieces || isSaving)
                    if isDetectingPieces { ProgressView() }
                    if let detectionMessage {
                        Text(detectionMessage).foregroundStyle(.secondary)
                    }
                }

                if !candidates.isEmpty {
                    Section {
                        Button("Add Missed Piece", action: addManualPiece)
                        Button("Enter One Piece Manually Instead") {
                            SharedImportDraftStore.removeAutomaticCutouts(for: candidates)
                            candidates = []
                            recognitionState = .manual
                        }
                    }
                    ForEach($candidates) { $candidate in
                        Section("Suggested piece") {
                            if let cropped = try? SharedImportDraftStore.imageData(for: candidate, in: image.data),
                               let preview = UIImage(data: cropped) {
                                Image(uiImage: preview)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: .infinity, maxHeight: 180)
                                    .accessibilityLabel("Suggested \(candidate.name) crop")
                            }
                            Toggle("Select this piece", isOn: $candidate.selected)
                            TextField("Piece name", text: $candidate.name)
                            Picker("Category", selection: $candidate.category) {
                                ForEach(ClothingCategory.allCases, id: \.self) { option in
                                    Text(option.rawValue.capitalized).tag(option)
                                }
                            }
                            Button("Adjust Image Region") { editingCandidateID = candidate.id }
                            Button("Remove Piece", role: .destructive) {
                                SharedImportDraftStore.removeAutomaticCutouts(for: [candidate])
                                candidates.removeAll { $0.id == candidate.id }
                            }
                            Text("Visual suggestion only. Check the image region and details.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        Button(isSaving ? "Saving…" : "Save Selected Pieces", action: saveSelectedPieces)
                            .disabled(isSaving || isDetectingPieces || !candidates.contains(where: \.selected))
                    }
                }

                if !possibleMissing.isEmpty {
                    Section {
                        ForEach(possibleMissing) { hint in
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Possible missing piece", tabler: "TablerHelpCircle")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.orange)
                                Text(hint.reason)
                                    .foregroundStyle(.secondary)
                                PhotosPicker(selection: $additionalPhoto, matching: .images) {
                                    Label("Add Another Photo", tabler: "TablerLibraryPhoto")
                                        .font(.footnote)
                                }
                                HStack {
                                    Button("Enter Manually") {
                                        addManualPiece()
                                        dismissPossiblePiece(hint.id)
                                    }
                                    Spacer()
                                    Button("Dismiss", role: .destructive) {
                                        dismissPossiblePiece(hint.id)
                                    }
                                }
                                .font(.footnote)
                            }
                            .padding(.vertical, 4)
                        }
                        Text("A possible piece is not a detected one and is never saved automatically. Choose another photo or enter it by hand to confirm it.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } header: {
                        Text("Possible Missing Piece")
                    }
                }

                if candidates.isEmpty {
                // MARK: - Preset Selection Section
                Section {
                    // Category filter tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PresetFilterCategory.allCases) { filter in
                                Button {
                                    activeFilter = filter
                                } label: {
                                    Text(filter.rawValue)
                                        .font(.caption.weight(activeFilter == filter ? .bold : .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            activeFilter == filter ? Color.accentColor : Color(.secondarySystemBackground),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(activeFilter == filter ? Color.white : Color.primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Horizontal Preset Cards
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(filteredPresets) { preset in
                                Button {
                                    selectPreset(preset)
                                } label: {
                                    VStack(spacing: 6) {
                                        DSIcon(preset.icon, size: 22)
                                            .foregroundStyle(selectedPreset == preset ? Color.white : Color.accentColor)
                                            .frame(height: 26)

                                        Text(preset.rawValue)
                                            .font(.caption2.weight(selectedPreset == preset ? .bold : .medium))
                                            .foregroundStyle(selectedPreset == preset ? Color.white : Color.primary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 84, height: 72)
                                    .background(
                                        selectedPreset == preset ? Color.accentColor : Color(.secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 12)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedPreset == preset ? Color.accentColor : Color.black.opacity(0.08), lineWidth: selectedPreset == preset ? 2 : 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Preset description
                    HStack(spacing: 6) {
                        DSIcon(selectedPreset.coversShoulders ? "TablerShieldFilled" : "TablerSparkles", size: 16)
                            .foregroundStyle(selectedPreset.coversShoulders ? .blue : .purple)
                        Text(selectedPreset.coverageDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                } header: {
                    Text("Avatar Preview")
                } footer: {
                    Text("Choose a visual preset to preview this piece on the avatar. This does not predict fit.")
                }

                // MARK: - Review & Name Section
                Section("Piece details") {
                    switch recognitionState {
                    case .analyzing:
                        HStack {
                            ProgressView()
                            Text("Filling preset with details from photo…")
                        }
                        Button("Enter details manually") {
                            detectionTask?.cancel()
                            isDetectingPieces = false
                            recognitionState = .manual
                        }
                    case .noMatch:
                        Text("Choose a preset above and name your piece.")
                            .foregroundStyle(.secondary)
                        Button("Try Recognition Again") { retryRecognition() }
                    case .failed:
                        Text("Could not analyze photo automatically. Select a preset above.")
                            .foregroundStyle(.secondary)
                        Button("Try Recognition Again") { retryRecognition() }
                    case .manual:
                        Text("Preset filled with photo colors. Review details below.")
                            .foregroundStyle(.secondary)
                    }

                    TextField("Name (for example, Blue \(selectedPreset.rawValue))", text: Binding(
                        get: { name },
                        set: { name = $0 }
                    ))

                    Picker("Category", selection: Binding(
                        get: { category },
                        set: { newCat in
                            category = newCat
                            hasEditedCategory = true
                            if selectedPreset.category != newCat {
                                selectPreset(GarmentPreset.detect(name: name, category: newCat))
                            }
                        }
                    )) {
                        ForEach(ClothingCategory.allCases, id: \.self) { option in
                            Text(option.rawValue.capitalized).tag(option)
                        }
                    }
                }

                // MARK: - Save Section
                Section {
                    Button(action: saveToCloset) {
                        HStack {
                            Spacer()
                            Text(isSaving ? "Saving to Closet…" : "Save to Closet")
                                .bold()
                            Spacer()
                        }
                    }
                    .disabled(isSaving || recognitionState == .analyzing || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                }

                if let saveError {
                    Section {
                        Text(saveError)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Review Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isSaving)
                }
            }
            .interactiveDismissDisabled(isSaving)
            .fullScreenCover(isPresented: Binding(
                get: { editingCandidateID != nil },
                set: { if !$0 { editingCandidateID = nil } }
            )) {
                if let id = editingCandidateID,
                   let candidate = candidates.first(where: { $0.id == id }) {
                    SharedImageRegionEditor(imageData: image.data, initial: candidate.region,
                                            initialOutline: candidate.outline) { region, outline in
                        if let index = candidates.firstIndex(where: { $0.id == id }) {
                            SharedImportDraftStore.removeAutomaticCutouts(for: [candidates[index]])
                            candidates[index].region = region
                            candidates[index].outline = outline
                            candidates[index].temporaryCutoutPath = nil
                        }
                        editingCandidateID = nil
                    }
                }
            }
            .task {
                guard !didStartPieceDetection else { return }
                didStartPieceDetection = true
                detectPieces()
            }
            .onChange(of: additionalPhoto) { _, item in
                guard let item else { return }
                Task {
                    defer { additionalPhoto = nil }
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          UIImage(data: data) != nil else { return }
                    detectionTask?.cancel()
                    onAnotherPhoto?(ReviewImage(id: UUID().uuidString, data: data,
                                                source: "Photo Library", isShared: false))
                }
            }
            .onDisappear {
                detectionTask?.cancel()
                SharedImportDraftStore.removeAutomaticCutouts(for: candidates)
            }
        }
    }

    // MARK: - Preview ViewBuilder

    @ViewBuilder
    private var previewContent: some View {
        switch previewMode {
        case .avatar3D:
            let previewItem = ClothingItem(
                id: image.id,
                ownerId: "current",
                name: selectedPreset.rawValue,
                category: category,
                imagePath: "",
                createdAt: Date()
            )
            ZStack(alignment: .bottom) {
                AvatarView(
                    look: [:],
                    worn: [category: previewItem],
                    image: { _ in Image(uiImage: stylizedResult?.image ?? UIImage()) },
                    uiImage: { _ in stylizedResult?.image },
                    zoom: 1.0,
                    use3D: true
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 4) {
                    DSIcon("TablerRefresh", size: 12)
                    Text("Drag to rotate 360°")
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.bottom, 8)
            }

        case .avatar2D:
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.96), Color(white: 0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 280)

                if let stylized = stylizedResult {
                    Image(uiImage: stylized.image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 250)
                        .padding(12)
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                } else {
                    ProgressView()
                }
            }

        case .original:
            if let uiImage = UIImage(data: image.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func selectPreset(_ preset: GarmentPreset) {
        selectedPreset = preset
        category = preset.category
        if !hasEditedName {
            name = preset.rawValue
        }
        // Re-fill the preset with the photo's extracted details
        Task {
            let result = await GarmentStylizer.convert(image.data, preferredCategory: preset.category, presetHint: preset)
            await MainActor.run {
                self.stylizedResult = result
            }
        }
    }

    private func retryRecognition() {
        recognitionState = .analyzing
        detectPieces()
    }

    private func detectPieces() {
        guard !isDetectingPieces else { return }
        isDetectingPieces = true
        detectionMessage = nil
        let attempt = UUID()
        detectionID = attempt
        detectionTask = Task {
            defer { if detectionID == attempt { isDetectingPieces = false } }
            do {
                let result = try await AutomaticImportSuggestions.review(imageData: image.data, importID: image.id)
                guard !Task.isCancelled else {
                    SharedImportDraftStore.removeAutomaticCutouts(for: result.candidates)
                    return
                }
                possibleMissing = result.possibleMissing
                candidates = SharedImportDraftStore.mergingSuggestions(result.candidates, into: candidates)
                recognitionState = result.candidates.isEmpty ? .noMatch : .manual
                if result.candidates.isEmpty {
                    detectionMessage = "No separate clothing pieces found. You can enter one piece manually below."
                }
            } catch is CancellationError {
                return
            } catch {
                recognitionState = .failed
                detectionMessage = "Could not find pieces automatically. You can enter one manually below."
            }
        }
    }

    private func dismissPossiblePiece(_ id: String) {
        possibleMissing.removeAll { $0.id == id }
    }

    private func addManualPiece() {
        let count = candidates.filter { $0.suggestionSource == nil }.count
        let id = SharedImportDraftStore.stableID(importID: image.id, part: "manual-\(count)")
        guard !candidates.contains(where: { $0.id == id }) else { return }
        candidates.append(ImportCandidate(
            id: id, name: "", category: .other, destination: .closet,
            temporaryCutoutPath: nil, region: nil, suggestionSource: nil,
            selected: false, tags: [], suggestedTags: []
        ))
        editingCandidateID = id
    }

    private func saveSelectedPieces() {
        guard !isSaving else { return }
        let selected = candidates.filter(\.selected)
        guard !selected.isEmpty else { return }
        isSaving = true
        var newlySaved: [String] = []
        do {
            let crops = try selected.map { candidate -> Data in
                guard !candidate.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw PrototypeImportError.emptyName
                }
                return try SharedImportDraftStore.imageData(for: candidate, in: image.data)
            }
            for (candidate, crop) in zip(selected, crops) {
                let existed = closet.item(id: candidate.id) != nil
                try closet.save(imageData: crop, draftId: candidate.id,
                                name: candidate.name, category: candidate.category)
                if !existed { newlySaved.append(candidate.id) }
            }
            onSaved()
        } catch {
            for id in newlySaved { try? closet.delete(id: id) }
            saveError = error.localizedDescription
        }
        isSaving = false
    }

    private func saveToCloset() {
        guard !isSaving else { return }
        isSaving = true
        do {
            try closet.save(imageData: image.data, draftId: image.id, name: name, category: category)
            GarmentPresetStore.set(selectedPreset, for: image.id)
            onSaved()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}
