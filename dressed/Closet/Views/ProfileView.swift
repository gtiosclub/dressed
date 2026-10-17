import SwiftUI

struct SavedOutfit: Identifiable {
    let id = UUID()
    var name: String
    var worn: [ClothingCategory: ClothingItem]
}

@Observable
final class OutfitStudioModel {
    var look: [AvatarPart: Int] = [:]
    var worn: [ClothingCategory: ClothingItem] = [:]
    var savedOutfits: [SavedOutfit] = []
    var zoom: Double = 1

    // Tapping the worn item again takes it off.
    func toggle(_ item: ClothingItem) {
        if worn[item.category]?.id == item.id {
            worn[item.category] = nil
        } else {
            worn[item.category] = item
        }
    }

    func saveCurrentOutfit() {
        savedOutfits.append(SavedOutfit(name: "Outfit \(savedOutfits.count + 1)", worn: worn))
    }

    func wearOutfit(id: UUID) {
        if let outfit = savedOutfits.first(where: { $0.id == id }) {
            worn = outfit.worn
        }
    }
}

enum StudioStep: Hashable { case customize, tryOn, fullBody, fullScreen, takePic }

// Profile tab: username + a small avatar. Tapping the avatar opens the studio:
// customize -> try on -> full body -> full screen -> take pic
// The model is owned by the parent so saved outfits can also show up in the closet's Outfits tab.
struct ProfileView: View {
    let username: String
    let items: [ClothingItem]
    let model: OutfitStudioModel
    let image: (ClothingItem) -> Image
    let onSignOut: () -> Void

    let uiImage: ((ClothingItem) -> UIImage?)?

    @State private var path: [StudioStep] = []

    init(
        username: String,
        items: [ClothingItem],
        model: OutfitStudioModel,
        onSignOut: @escaping () -> Void,
        image: @escaping (ClothingItem) -> Image = { _ in Image(systemName: "photo") },
        uiImage: ((ClothingItem) -> UIImage?)? = nil
    ) {
        self.username = username
        self.items = items
        self.model = model
        self.onSignOut = onSignOut
        self.image = image
        self.uiImage = uiImage
    }

    var body: some View {
        NavigationStack(path: $path) {
            ProfileHome(username: username, model: model, image: image, uiImage: uiImage, onSignOut: onSignOut) {
                path.append(.customize)
            }
            .navigationDestination(for: StudioStep.self) { step in
                switch step {
                case .customize:
                    AvatarCustomizationScreen(model: model, image: image, uiImage: uiImage) { path.append(.tryOn) }
                case .tryOn:
                    TryOnScreen(model: model, items: items, image: image, uiImage: uiImage) { path.append(.fullBody) }
                case .fullBody:
                    FullBodyScreen(model: model, image: image, uiImage: uiImage) { path.append(.fullScreen) }
                case .fullScreen:
                    FullScreenAvatar(model: model, image: image, uiImage: uiImage) { path.append(.takePic) }
                case .takePic:
                    TakePicScreen(model: model, image: image, uiImage: uiImage)
                }
            }
        }
    }
}

// MARK: - Profile home

private struct ProfileHome: View {
    let username: String
    let model: OutfitStudioModel
    let image: (ClothingItem) -> Image
    var uiImage: ((ClothingItem) -> UIImage?)? = nil
    let onSignOut: () -> Void
    let onEditAvatar: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button(action: onEditAvatar) {
                    // Fixed zoom so the profile picture doesn't inherit the studio's zoom slider.
                    AvatarView(look: model.look, worn: model.worn, image: image, uiImage: uiImage, zoom: 1)
                        .allowsHitTesting(false)   // the button handles taps, not the spin gesture
                        .frame(width: 140, height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .contentShape(RoundedRectangle(cornerRadius: 16))   // keeps the whole avatar tappable
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(8)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit avatar")

                Text(username).font(.title2.bold())

                Button("Edit avatar", action: onEditAvatar)
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Sign Out", action: onSignOut)
            }
        }
    }
}

// MARK: - Shared

private struct ZoomSlider: View {
    @Binding var zoom: Double

    var body: some View {
        Slider(value: $zoom, in: 1...2)
            .frame(width: 160)
            .rotationEffect(.degrees(-90))
            .frame(width: 30, height: 160)
    }
}

// MARK: - 1. Avatar customization

private struct AvatarCustomizationScreen: View {
    @Bindable var model: OutfitStudioModel
    let image: (ClothingItem) -> Image
    var uiImage: ((ClothingItem) -> UIImage?)? = nil
    let onDone: () -> Void

    @State private var part: AvatarPart = .gender

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                AvatarView(look: model.look, worn: model.worn, image: image, uiImage: uiImage, zoom: model.zoom)
                ZoomSlider(zoom: $model.zoom).padding(.trailing, 8)
            }

            VStack(spacing: 12) {
                partChips

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<part.optionCount, id: \.self) { index in
                            optionTile(index)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .padding()
            .background(.thinMaterial)
        }
        .navigationTitle("User avatar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Done", action: onDone) }
        }
    }

    // Seven parts don't fit a segmented control, so these scroll.
    private var partChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AvatarPart.allCases) { candidate in
                    Button { part = candidate } label: {
                        Text(candidate.title)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .foregroundStyle(part == candidate ? Color.white : Color.primary)
                            .background(part == candidate ? Color.accentColor : Color.gray.opacity(0.15), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func optionTile(_ index: Int) -> some View {
        let isSelected = part.selection(in: model.look) == index
        let swatch = part.swatch(index)
        let preview = AvatarPreviews.image(for: part, index: index, in: model.look)

        return Button {
            model.look[part] = index
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(swatch ?? Color.gray.opacity(0.15))
                if let preview {
                    VStack(spacing: 0) {
                        Image(uiImage: preview)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 92)
                        Text(part.label(index, in: model.look))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else if swatch == nil {
                    Text(part.label(index, in: model.look)).font(.caption).foregroundStyle(.secondary)
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
}

// MARK: - 2. Clothes try-on

private struct TryOnScreen: View {
    @Bindable var model: OutfitStudioModel
    let items: [ClothingItem]
    let image: (ClothingItem) -> Image
    var uiImage: ((ClothingItem) -> UIImage?)? = nil
    let onDone: () -> Void

    @State private var tab = 0  // 0 = Clothing, 1 = Saved fits
    @State private var category: ClothingCategory? = nil  // nil = All

    private var filteredItems: [ClothingItem] {
        guard let category else { return items }
        return items.filter { $0.category == category }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .trailing) {
                AvatarView(look: model.look, worn: model.worn, image: image, uiImage: uiImage, zoom: model.zoom)
                ZoomSlider(zoom: $model.zoom).padding(.trailing, 8)
            }

            Picker("Source", selection: $tab) {
                Text("Clothing").tag(0)
                Text("Saved fits").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if tab == 0 {
                CategorySelector(selection: $category)
                clothingTray
            } else {
                savedFitsTray
            }
        }
        .navigationTitle("Try on")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button("Done", action: onDone) }
        }
    }

    // Tray of clothing items in the selected category. Tap one to put it on (tap again to take it off).
    @ViewBuilder
    private var clothingTray: some View {
        // OutfitItemTray identifies items by UUID, so pair each tray item with its ClothingItem.
        let entries = filteredItems.map { clothing in
            (
                clothing: clothing,
                tray: OutfitItem(
                    id: UUID(),
                    image: image(clothing),
                    name: clothing.name,
                    category: clothing.category
                )
            )
        }

        OutfitItemTray(items: entries.map { $0.tray }) { id in
            if let entry = entries.first(where: { $0.tray.id == id }) {
                model.toggle(entry.clothing)
            }
        }
    }

    // Tray of previously saved outfits. Tap one to put the whole outfit on.
    private var savedFitsTray: some View {
        OutfitItemTray(
            items: model.savedOutfits.map { outfit in
                OutfitItem(
                    id: outfit.id,
                    image: Image(systemName: "figure.stand"),
                    name: outfit.name,
                    category: .tops,  // not shown; subtitle replaces the category label
                    subtitle: "\(outfit.worn.count) pieces"
                )
            },
            onSelect: { model.wearOutfit(id: $0) }
        )
    }
}

// MARK: - 3. Full body with buttons

private struct FullBodyScreen: View {
    @Bindable var model: OutfitStudioModel
    let image: (ClothingItem) -> Image
    var uiImage: ((ClothingItem) -> UIImage?)? = nil
    let onFullScreen: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            AvatarView(look: model.look, worn: model.worn, image: image, uiImage: uiImage, zoom: model.zoom)
            wornList.padding(8)
        }
        .navigationTitle("User avatar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { model.saveCurrentOutfit() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onFullScreen) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
            }
        }
    }

    // Clothes the avatar is wearing. Tap one to take it off.
    private var wornList: some View {
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
                }
            }
        }
    }
}

// MARK: - 4. Full screen

private struct FullScreenAvatar: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: OutfitStudioModel
    let image: (ClothingItem) -> Image
    var uiImage: ((ClothingItem) -> UIImage?)? = nil
    let onTakePic: () -> Void

    var body: some View {
        ZStack {
            AvatarView(look: model.look, worn: model.worn, image: image, uiImage: uiImage, zoom: model.zoom)
                .ignoresSafeArea()

            HStack {
                Spacer()
                ZoomSlider(zoom: $model.zoom).padding(.trailing, 8)
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill").font(.title)
                    }
                }
                Spacer()
                Button("Take a pic", action: onTakePic)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - 5. Take pic

private struct TakePicScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: OutfitStudioModel
    let image: (ClothingItem) -> Image
    var uiImage: ((ClothingItem) -> UIImage?)? = nil

    @State private var snapshot: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title)
                }
            }

            AvatarView(look: model.look, worn: model.worn, image: image, uiImage: uiImage, zoom: model.zoom)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 16) {
                if let snapshot {
                    ShareLink(
                        item: Image(uiImage: snapshot),
                        preview: SharePreview("My outfit", image: Image(uiImage: snapshot))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        UIImageWriteToSavedPhotosAlbum(snapshot, nil, nil, nil)
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { snapshot = render() }
    }

    private func render() -> UIImage? {
        let renderer = ImageRenderer(
            content: AvatarView(look: model.look, worn: model.worn, image: image, uiImage: uiImage, zoom: model.zoom, use3D: false)
                .frame(width: 300, height: 450)
        )
        renderer.scale = 3
        return renderer.uiImage
    }
}

#Preview {
    ProfileView(username: "aditya", items: ClothingItem.previewSamples, model: OutfitStudioModel(), onSignOut: {})
}
