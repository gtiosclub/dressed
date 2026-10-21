import SwiftUI

/// Main Avatar Studio view where the user tries on clothing pieces and outfits in 360 degrees,
/// customizes avatar appearance, saves outfits, and captures photos.
struct AvatarStudioView: View {
    @Bindable var model: OutfitStudioModel
    var closet: PrototypeClosetStore? = nil
    let items: [ClothingItem]
    let image: (ClothingItem) -> Image
    var uiImage: ((ClothingItem) -> UIImage?)? = nil

    enum StudioTab: String, CaseIterable, Identifiable {
        case tryOn = "Try On"
        case customize = "Customize"
        case fullBody = "Full Body"

        var id: String { rawValue }
    }

    private struct ItemDetailSheet: Identifiable {
        let id: String
    }

    @State private var activeTab: StudioTab = .tryOn
    @State private var showingTakePic = false
    @State private var itemDetailSheet: ItemDetailSheet? = nil
    @State private var outfitSavedAlert = false

    var body: some View {
        VStack(spacing: 0) {
            Picker("Mode", selection: $activeTab) {
                ForEach(StudioTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 4)

            switch activeTab {
            case .tryOn:
                studioTryOnContent
            case .customize:
                studioCustomizeContent
            case .fullBody:
                studioFullBodyContent
            }
        }
        .navigationTitle("Avatar Studio")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    model.saveCurrentOutfit()
                    outfitSavedAlert = true
                } label: {
                    Label("Save Outfit", systemImage: "heart")
                }
                .disabled(model.worn.isEmpty)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingTakePic = true
                } label: {
                    Image(systemName: "camera")
                }
                .accessibilityLabel("Take photo of avatar")
            }
        }
        .alert("Outfit Saved", isPresented: $outfitSavedAlert) {
            Button("OK", role: .cancel) { outfitSavedAlert = false }
        } message: {
            Text("Find it under Saved Fits in Try On.")
        }
        .sheet(isPresented: $showingTakePic) {
            NavigationStack {
                StudioTakePicView(model: model, image: image, uiImage: uiImage)
            }
        }
        .sheet(item: $itemDetailSheet) { sheet in
            if let closet {
                NavigationStack {
                    PrototypeItemDetailView(closet: closet, itemID: sheet.id)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { itemDetailSheet = nil }
                            }
                        }
                }
            }
        }
    }

    // MARK: - 1. Try On Mode

    @State private var trayCategory: ClothingCategory? = nil
    @State private var traySource = 0 // 0 = Clothing, 1 = Saved fits

    private var filteredItems: [ClothingItem] {
        guard let trayCategory else { return items }
        return items.filter { $0.category == trayCategory }
    }

    private var studioTryOnContent: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .trailing) {
                AvatarView(
                    look: model.look,
                    worn: model.worn,
                    image: image,
                    uiImage: uiImage,
                    zoom: model.zoom
                )
                StudioZoomSlider(zoom: $model.zoom).padding(.trailing, 8)
            }

            // Currently worn quick chips
            if !model.worn.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ClothingCategory.layerOrder, id: \.self) { cat in
                            if let wornItem = model.worn[cat] {
                                Button {
                                    model.worn[cat] = nil
                                } label: {
                                    HStack(spacing: 6) {
                                        image(wornItem)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 20, height: 20)
                                        Text(wornItem.name)
                                            .font(.caption.weight(.medium))
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption2)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(.ultraThinMaterial, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Inspect Details") {
                                        itemDetailSheet = ItemDetailSheet(id: wornItem.id)
                                    }
                                    Button("Remove from Avatar", role: .destructive) {
                                        model.worn[cat] = nil
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 32)
            }

            Picker("Source", selection: $traySource) {
                Text("Closet Pieces").tag(0)
                Text("Saved Fits").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if traySource == 0 {
                CategorySelector(selection: $trayCategory)
                clothingTray
            } else {
                savedFitsTray
            }
        }
    }

    // The tray thumbnails are flat pictures on purpose. Each live 3D avatar holds a GPU drawable, and
    // one per closet item ran the device out of them ("nextDrawable returning nil"), which froze the
    // main avatar so outfit changes seemed not to work.
    private var clothingTray: some View {
        let entries = filteredItems.map { clothing in
            (
                clothing: clothing,
                tray: OutfitItem(
                    // Stable per closet item so SwiftUI keeps each tray cell between renders.
                    id: Self.stableID(for: clothing.id),
                    thumbnail: AnyView(
                        image(clothing)
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    ),
                    name: clothing.name,
                    category: clothing.category
                )
            )
        }

        return OutfitItemTray(items: entries.map { $0.tray }) { id in
            guard let entry = entries.first(where: { $0.tray.id == id }) else {
                return
            }

            let item = entry.clothing
            let category = item.category

            // Tapping the item that's already worn removes it.
            if model.worn[category]?.id == item.id {
                model.worn[category] = nil
            } else {
                // Replace whatever is currently worn in this category.
                model.worn[category] = item
            }
        }
    }

    /// A UUID that is the same every time for the same closet item id.
    private static func stableID(for string: String) -> UUID {
        if let uuid = UUID(uuidString: string) { return uuid }
        var first: UInt64 = 14695981039346656037   // FNV-1a
        var second: UInt64 = 5381                  // djb2
        for byte in string.utf8 {
            first = (first ^ UInt64(byte)) &* 1099511628211
            second = (second &* 33) &+ UInt64(byte)
        }
        let digits = Array(String(format: "%016llX%016llX", first, second))
        let formatted = [0..<8, 8..<12, 12..<16, 16..<20, 20..<32]
            .map { String(digits[$0]) }
            .joined(separator: "-")
        return UUID(uuidString: formatted) ?? UUID()
    }

    private var savedFitsTray: some View {
        OutfitItemTray(
            items: model.savedOutfits.map { outfit in
                OutfitItem(
                    id: outfit.id,
                    thumbnail: AnyView(SavedFitThumbnail(worn: outfit.worn, image: image)),
                    name: outfit.name,
                    category: .tops,
                    subtitle: "\(outfit.worn.count) pieces"
                )
            },
            onSelect: { model.wearOutfit(id: $0) }
        )
    }

    // MARK: - 2. Customize Mode

    @State private var customizePart: AvatarPart = .gender

    private var studioCustomizeContent: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                AvatarView(
                    look: model.look,
                    worn: model.worn,
                    image: image,
                    uiImage: uiImage,
                    zoom: model.zoom
                )
                StudioZoomSlider(zoom: $model.zoom).padding(.trailing, 8)
            }

            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AvatarPart.allCases) { candidate in
                            Button {
                                customizePart = candidate
                            } label: {
                                Text(candidate.title)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .foregroundStyle(customizePart == candidate ? Color.white : Color.primary)
                                    .background(customizePart == candidate ? Color.accentColor : Color.gray.opacity(0.15), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<customizePart.optionCount, id: \.self) { index in
                            customizeOptionTile(index)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 10)
            .background(.thinMaterial)
        }
    }

    private func customizeOptionTile(_ index: Int) -> some View {
        let isSelected = customizePart.selection(in: model.look) == index
        let swatch = customizePart.swatch(index)
        let preview = AvatarPreviews.image(for: customizePart, index: index, in: model.look)

        return Button {
            model.look[customizePart] = index
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(swatch ?? Color.gray.opacity(0.15))
                if let preview {
                    VStack(spacing: 0) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 92)
                        Text(customizePart.label(index, in: model.look))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else if swatch == nil {
                    Text(customizePart.label(index, in: model.look))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 90, height: 118)
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. Full Body Mode

    private var studioFullBodyContent: some View {
        ZStack(alignment: .topLeading) {
            AvatarView(
                look: model.look,
                worn: model.worn,
                image: image,
                uiImage: uiImage,
                zoom: model.zoom
            )

            VStack(spacing: 8) {
                ForEach(ClothingCategory.layerOrder, id: \.self) { category in
                    if let item = model.worn[category] {
                        Button {
                            model.worn[category] = nil
                        } label: {
                            image(item)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 44, height: 44)
                                .padding(4)
                                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(item.name)")
                    }
                }
            }
            .padding(12)
        }
    }
}

// MARK: - Saved fit thumbnail

/// A flat, lightweight picture of a saved outfit: its pieces laid out where they sit on the body.
/// Plain SwiftUI images, so it costs nothing next to a live 3D scene.
private struct SavedFitThumbnail: View {
    let worn: [ClothingCategory: ClothingItem]
    let image: (ClothingItem) -> Image

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.gray.opacity(0.12)
                ForEach(ClothingCategory.layerOrder, id: \.self) { category in
                    if let item = worn[category] {
                        let slot = category.avatarSlot
                        image(item)
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width * 0.6, height: geo.size.height * slot.size)
                            .position(x: geo.size.width / 2, y: geo.size.height * slot.y)
                    }
                }
            }
        }
    }
}

// MARK: - Zoom Slider

private struct StudioZoomSlider: View {
    @Binding var zoom: Double

    var body: some View {
        Slider(value: $zoom, in: 1...2)
            .frame(width: 160)
            .rotationEffect(.degrees(-90))
            .frame(width: 30, height: 160)
    }
}

// MARK: - Take Pic View

private struct StudioTakePicView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: OutfitStudioModel
    let image: (ClothingItem) -> Image
    var uiImage: ((ClothingItem) -> UIImage?)? = nil

    @State private var snapshot: UIImage?

    var body: some View {
        VStack(spacing: 20) {
            AvatarView(
                look: model.look,
                worn: model.worn,
                image: image,
                uiImage: uiImage,
                zoom: model.zoom
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, maxHeight: 420)
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)

            HStack(spacing: 16) {
                if let snapshot {
                    ShareLink(
                        item: Image(uiImage: snapshot),
                        preview: SharePreview("My 3D Outfit", image: Image(uiImage: snapshot))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        UIImageWriteToSavedPhotosAlbum(snapshot, nil, nil, nil)
                    } label: {
                        Label("Save Photo", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Snapshot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear { snapshot = render() }
    }

    private func render() -> UIImage? {
        let renderer = ImageRenderer(
            content: AvatarView(
                look: model.look,
                worn: model.worn,
                image: image,
                uiImage: uiImage,
                zoom: model.zoom,
                use3D: false
            )
            .frame(width: 320, height: 480)
        )
        renderer.scale = 3
        return renderer.uiImage
    }
}
