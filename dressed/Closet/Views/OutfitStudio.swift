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

enum StudioStep: Hashable { case tryOn, fullBody, fullScreen, takePic }

// Wireflow: customize -> try on -> full body -> full screen -> take pic
// The model is owned by the parent so saved outfits can also show up in the closet's Outfits tab.
struct OutfitStudioView: View {
    let items: [ClothingItem]
    let model: OutfitStudioModel
    let image: (ClothingItem) -> Image

    @State private var path: [StudioStep] = []

    init(
        items: [ClothingItem],
        model: OutfitStudioModel,
        image: @escaping (ClothingItem) -> Image = { _ in Image(systemName: "photo") }
    ) {
        self.items = items
        self.model = model
        self.image = image
    }

    var body: some View {
        NavigationStack(path: $path) {
            AvatarCustomizationScreen(model: model, image: image) { path.append(.tryOn) }
                .navigationDestination(for: StudioStep.self) { step in
                    switch step {
                    case .tryOn:
                        TryOnScreen(model: model, items: items, image: image) { path.append(.fullBody) }
                    case .fullBody:
                        FullBodyScreen(model: model, image: image) { path.append(.fullScreen) }
                    case .fullScreen:
                        FullScreenAvatar(model: model, image: image) { path.append(.takePic) }
                    case .takePic:
                        TakePicScreen(model: model, image: image)
                    }
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
    let onDone: () -> Void

    @State private var part: AvatarPart = .bangs

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .trailing) {
                AvatarView(look: model.look, worn: model.worn, image: image, zoom: model.zoom)
                ZoomSlider(zoom: $model.zoom).padding(.trailing, 8)
            }

            VStack(spacing: 12) {
                Picker("Part", selection: $part) {
                    ForEach(AvatarPart.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<8, id: \.self) { index in
                            optionTile(index)
                        }
                    }
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

    private func optionTile(_ index: Int) -> some View {
        let isSelected = model.look[part] == index
        let fill: Color = part == .body
            ? AvatarView.bodyTints[index % AvatarView.bodyTints.count]
            : Color.gray.opacity(0.25)

        return Button {
            model.look[part] = index
        } label: {
            RoundedRectangle(cornerRadius: 12)
                .fill(fill)
                .frame(width: 90, height: 90)
                .overlay {
                    if part != .body { Text("\(index + 1)").foregroundStyle(.secondary) }
                }
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
                AvatarView(look: model.look, worn: model.worn, image: image, zoom: model.zoom)
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
    let onFullScreen: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            AvatarView(look: model.look, worn: model.worn, image: image, zoom: model.zoom)
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
    let onTakePic: () -> Void

    var body: some View {
        ZStack {
            AvatarView(look: model.look, worn: model.worn, image: image, zoom: model.zoom)
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

    @State private var snapshot: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title)
                }
            }

            AvatarView(look: model.look, worn: model.worn, image: image, zoom: model.zoom)
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
            content: AvatarView(look: model.look, worn: model.worn, image: image, zoom: model.zoom)
                .frame(width: 300, height: 450)
        )
        renderer.scale = 3
        return renderer.uiImage
    }
}

#Preview {
    OutfitStudioView(items: ClothingItem.previewSamples, model: OutfitStudioModel())
}
