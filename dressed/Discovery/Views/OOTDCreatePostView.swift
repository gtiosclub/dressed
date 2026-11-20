import PhotosUI
import SwiftUI

struct OOTDCreatePostView: View {
    let canShare: Bool
    let isDemo: Bool
    let onShare: (PostPublicationDraft) async throws -> Void
    @StateObject private var model: PostComposerModel
    @Environment(\.dismiss) private var dismiss
    @State private var photoSelection: PhotosPickerItem?
    @State private var showingItems = false
    @State private var shareTask: Task<Void, Never>?

    init(canShare: Bool, isDemo: Bool = false, source: (any PostCompositionSource)? = nil,
         onShare: @escaping (PostPublicationDraft) async throws -> Void) {
        self.canShare = canShare
        self.isDemo = isDemo
        self.onShare = onShare
        _model = StateObject(wrappedValue: PostComposerModel(source: source))
    }

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            DSBackHeader(title: "New post", onBack: { dismiss() })
                .disabled(model.isSharing)
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    photoPicker
                    TextField("Write a caption…", text: $model.caption, axis: .vertical)
                        .lineLimit(2...4)
                        .font(DSFont.body)
                        .padding(DSSpacing.md)
                        .background(DSColor.tile, in: RoundedRectangle(cornerRadius: DSRadius.md))
                        .disabled(model.isLocked)
                        .accessibilityIdentifier("ootd.newPostCaption")
                    Text("\(model.caption.count)/500 characters")
                        .font(DSFont.search)
                        .foregroundStyle(DSColor.textMuted)
                    Button { showingItems = true } label: {
                        HStack(spacing: DSSpacing.sm) {
                            DSIcon("TablerHanger2", size: 24)
                            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                Text("Outfit details").font(DSFont.bodyEmphasis)
                                Text(model.selectedIds.isEmpty ? "Tag items or choose a saved outfit" : "\(model.selectedIds.count) items tagged")
                                    .font(DSFont.search)
                            }
                            Spacer()
                            DSIcon("TablerChevronRight", size: 20)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.ds(.secondary))
                    .disabled(model.isLocked)
                    .accessibilityIdentifier("ootd.newPost.Outfit details")
                    if let name = model.outfitName { Text(name).font(DSFont.bodyEmphasis) }
                    ForEach(model.items.filter { model.selectedIds.contains($0.id) }) { item in
                        DSItemRow(title: item.name) { thumbnail(item) }
                    }
                    Text(isDemo ? "Demo preview only. This post and its photos are not uploaded to Firebase." :
                            "Share publishes this photo and copies of the tagged items to signed-in members. Your private closet stays private.")
                        .font(DSFont.search)
                        .foregroundStyle(DSColor.textMuted)
                    if let error = model.error {
                        Text(error).font(DSFont.body).foregroundStyle(DSColor.textPrimary)
                            .accessibilityIdentifier("ootd.shareError")
                    }
                }
            }
            Button {
                shareTask = Task { await model.submit(onShare: onShare) }
            } label: {
                HStack {
                    if model.isSharing { ProgressView().tint(DSColor.background) }
                    Text(model.pendingDraft == nil ? "Share" : "Retry Share")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.ds(.primary))
            .disabled(!canShare || !model.canSubmit)
            .opacity(canShare && model.canSubmit ? 1 : 0.5)
            .accessibilityIdentifier("ootd.sharePreview")
        }
        .padding(DSSpacing.lg)
        .background(DSColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { model.load() }
        .task(id: photoSelection) { await model.loadPhoto(photoSelection) }
        .onDisappear { shareTask?.cancel() }
        .sheet(isPresented: $showingItems) { itemPicker }
    }

    private var photoPicker: some View {
        let photo = model.photo
        let isLoading = model.isLoadingPhoto
        return PhotosPicker(selection: $photoSelection, matching: .images) {
            VStack(spacing: DSSpacing.sm) {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFit().frame(height: 240)
                        .accessibilityLabel("Selected post photo")
                    Text("Change photo").font(DSFont.button)
                } else if isLoading {
                    ProgressView("Loading photo…")
                } else {
                    DSIcon("TablerPhoto", size: 48)
                    Text("Choose post photo").font(DSFont.bodyEmphasis)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 180)
            .padding(DSSpacing.md)
            .background(DSColor.tile, in: RoundedRectangle(cornerRadius: DSRadius.lg))
        }
        .buttonStyle(.plain)
        .disabled(model.isLocked)
        .accessibilityIdentifier("ootd.choosePhoto")
    }

    private var itemPicker: some View {
        NavigationStack {
            List {
                if !model.outfits.isEmpty {
                    Section("Saved outfits") {
                        ForEach(model.outfits) { outfit in
                            Button {
                                model.select(outfit)
                            } label: {
                                HStack {
                                    Text(outfit.name ?? "Outfit")
                                    Spacer()
                                    Text("\(outfit.placements.count) items").foregroundStyle(DSColor.textMuted)
                                }
                            }
                            .accessibilityIdentifier("ootd.outfit.\(outfit.id)")
                        }
                    }
                }
                Section("My Closet · choose up to 10 pieces") {
                    if model.items.isEmpty {
                        Text("Add pieces to My Closet before tagging an outfit.")
                    }
                    ForEach(model.items) { item in
                        Button { model.toggle(item) } label: {
                            HStack(spacing: DSSpacing.md) {
                                thumbnail(item).frame(width: 48, height: 48)
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                    Text(item.category.rawValue.capitalized).font(DSFont.search).foregroundStyle(DSColor.textMuted)
                                }
                                Spacer()
                                DSSelectionMark(isChecked: model.selectedIds.contains(item.id))
                            }
                        }
                        .accessibilityIdentifier("ootd.tag.\(item.id)")
                        .accessibilityAddTraits(model.selectedIds.contains(item.id) ? .isSelected : [])
                    }
                }
                if let error = model.error { Text(error) }
            }
            .font(DSFont.body)
            .foregroundStyle(DSColor.textPrimary)
            .navigationTitle("Outfit details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingItems = false } } }
        }
    }

    @ViewBuilder private func thumbnail(_ item: ClothingItem) -> some View {
        if let image = model.thumbnail(for: item) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            DSIcon("TablerPhoto", size: 24).foregroundStyle(DSColor.iconMuted)
        }
    }
}
