import PhotosUI
import SwiftUI
import UIKit

struct PrototypeImportView: View {
    @ObservedObject var closet: PrototypeClosetStore
    let ownerId: String
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var review: ReviewImage?
    @State private var showsCamera = false
    @State private var capturedImage: UIImage?
    @State private var importError: String?
    @State private var productURLText = ""
    @State private var productLink: ReviewProductLink?
    @FocusState private var productURLFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Add a piece")
                .font(.title2.bold())
            Text("Choose or capture a clothing photo. Review the suggested details before it enters your closet.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Choose from Photos", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showsCamera = true
                } else {
                    importError = "Camera is unavailable on this device. Choose a photo instead."
                }
            } label: {
                Label("Take a Photo", systemImage: "camera")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text("You can also share an image to Dressed from another app, then open Dressed to review it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 10) {
                Text("Save a product link").font(.headline)
                TextField("https://store.example/product", text: $productURLText)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("productURLField")
                    .focused($productURLFocused)
                    .submitLabel(.done)
                    .onSubmit { productURLFocused = false }
                Button("Review Product Link") {
                    productURLFocused = false
                    guard let url = ProductLinkValidation.normalize(productURLText) else {
                        importError = ProductLinkError.invalidURL.localizedDescription
                        return
                    }
                    productLink = ReviewProductLink(id: UUID().uuidString, url: url, isShared: false)
                }
                .buttonStyle(.bordered)
                Text("Product links go to Wishlist after review; they do not become owned closet pieces.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Camera")
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            Task {
                defer { selectedPhoto = nil }
                do {
                    guard let data = try await photo.loadTransferable(type: Data.self),
                          UIImage(data: data) != nil else {
                        throw PrototypeImportError.invalidImage
                    }
                    review = ReviewImage(id: UUID().uuidString, data: data, source: "Photo Library", isShared: false)
                } catch {
                    importError = error.localizedDescription
                }
            }
        }
        .sheet(isPresented: $showsCamera, onDismiss: {
            guard let capturedImage else { return }
            self.capturedImage = nil
            guard let data = capturedImage.jpegData(compressionQuality: 0.85) else {
                importError = PrototypeImportError.invalidImage.localizedDescription
                return
            }
            review = ReviewImage(id: UUID().uuidString, data: data, source: "Camera", isShared: false)
        }) {
            PrototypeCameraPicker { image in
                capturedImage = image
                showsCamera = false
            }
        }
        .sheet(item: $review) { image in
            ImportReviewView(
                image: image,
                closet: closet,
                onCancel: { review = nil },
                onSaved: { review = nil }
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
}

struct ImportReviewView: View {
    let image: ReviewImage
    @ObservedObject var closet: PrototypeClosetStore
    let onCancel: () -> Void
    let onSaved: () -> Void

    private enum RecognitionState: Equatable {
        case analyzing
        case suggested
        case noMatch
        case failed
        case manual
    }

    @State private var name = ""
    @State private var category: ClothingCategory = .other
    @State private var hasEditedName = false
    @State private var hasEditedCategory = false
    @State private var recognitionState: RecognitionState = .analyzing
    @State private var recognitionAttempt = 0
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var candidates: [ImportCandidate] = []
    @State private var isDetectingPieces = false
    @State private var detectionMessage: String?
    @State private var editingCandidateID: String?
    @State private var didStartPieceDetection = false
    @State private var detectionTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let uiImage = UIImage(data: image.data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(maxHeight: 300)
                            .accessibilityLabel("Image to import")
                    }
                    Text(image.source)
                        .foregroundStyle(.secondary)
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

                if candidates.isEmpty { Section("Review this piece") {
                    switch recognitionState {
                    case .analyzing:
                        HStack {
                            ProgressView()
                            Text("Looking for clothing…")
                        }
                        Button("Enter details manually") {
                            recognitionState = .manual
                            recognitionAttempt += 1
                        }
                    case .suggested:
                        Label("Suggested from this photo", systemImage: "sparkles")
                            .foregroundStyle(.secondary)
                    case .noMatch:
                        Text("No clothing suggestion found. Enter the details yourself.")
                            .foregroundStyle(.secondary)
                        Button("Try Recognition Again") { retryRecognition() }
                    case .failed:
                        Text("Could not analyze this photo. You can still enter the details yourself.")
                            .foregroundStyle(.secondary)
                        Button("Try Recognition Again") { retryRecognition() }
                    case .manual:
                        Text("Enter the details for this photo.")
                            .foregroundStyle(.secondary)
                    }
                    TextField("Name (for example, Blue shirt)", text: Binding(
                        get: { name },
                        set: { name = $0; hasEditedName = true }
                    ))
                    Picker("Category", selection: Binding(
                        get: { category },
                        set: { category = $0; hasEditedCategory = true }
                    )) {
                        ForEach(ClothingCategory.allCases, id: \.self) { option in
                            Text(option.rawValue.capitalized).tag(option)
                        }
                    }
                    Text("This checks the whole image for one garment. It cannot separate pieces or identify an exact product. Check the details before saving.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(action: saveToCloset) {
                        HStack {
                            Spacer()
                            Text(isSaving ? "Saving…" : "Save to Closet")
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
            .sheet(isPresented: Binding(
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
            .task(id: recognitionAttempt) {
                guard recognitionState == .analyzing else { return }
                do {
                    let suggestion = try await PrototypeGarmentRecognition.analyze(image.data)
                    guard !Task.isCancelled, recognitionState == .analyzing else { return }
                    if let suggestion {
                        if !hasEditedName { name = suggestion.name }
                        if !hasEditedCategory { category = suggestion.category }
                        recognitionState = .suggested
                    } else {
                        recognitionState = .noMatch
                    }
                } catch is CancellationError {
                    // Dismissing or choosing manual entry must not update a stale review.
                } catch {
                    guard !Task.isCancelled, recognitionState == .analyzing else { return }
                    recognitionState = .failed
                }
            }
            .task {
                guard !didStartPieceDetection else { return }
                didStartPieceDetection = true
                detectPieces()
            }
            .onDisappear {
                detectionTask?.cancel()
                SharedImportDraftStore.removeAutomaticCutouts(for: candidates)
            }
        }
    }

    private func retryRecognition() {
        recognitionState = .analyzing
        recognitionAttempt += 1
    }

    private func detectPieces() {
        guard !isDetectingPieces else { return }
        isDetectingPieces = true
        detectionMessage = nil
        detectionTask = Task {
            defer { isDetectingPieces = false }
            do {
                let found = try await AutomaticImportSuggestions.detect(imageData: image.data, importID: image.id)
                guard !Task.isCancelled else {
                    SharedImportDraftStore.removeAutomaticCutouts(for: found)
                    return
                }
                let previous = Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0) })
                let manual = candidates.filter { $0.suggestionSource == nil }
                candidates = found.map { previous[$0.id] ?? $0 } + manual
                if found.isEmpty {
                    detectionMessage = "No separate clothing pieces found. You can enter one piece manually below."
                }
            } catch {
                detectionMessage = "Could not find pieces automatically. You can enter one manually below."
            }
        }
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
            onSaved()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}

private struct PrototypeCameraPicker: UIViewControllerRepresentable {
    let onResult: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onResult: (UIImage?) -> Void

        init(onResult: @escaping (UIImage?) -> Void) {
            self.onResult = onResult
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onResult(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onResult(nil)
        }
    }
}
