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
    // Tapping another item in the same category replaces it.
    func toggle(_ item: ClothingItem) {
        if worn[item.category]?.id == item.id {
            worn[item.category] = nil
        } else {
            worn[item.category] = item
        }
    }

    func saveCurrentOutfit() {
        savedOutfits.append(
            SavedOutfit(
                name: "Outfit \(savedOutfits.count + 1)",
                worn: worn
            )
        )
    }

    func wearOutfit(id: UUID) {
        if let outfit = savedOutfits.first(where: { $0.id == id }) {
            worn = outfit.worn
        }
    }
}

// MARK: - Avatar Studio

struct ProfileView: View {
    let username: String
    let items: [ClothingItem]
    let model: OutfitStudioModel
    @ObservedObject var outfits: PrototypeOutfitStore

    var closet: PrototypeClosetStore? = nil

    let image: (ClothingItem) -> Image
    let onSignOut: () -> Void

    let uiImage: ((ClothingItem) -> UIImage?)?

    init(
        username: String,
        items: [ClothingItem],
        model: OutfitStudioModel,
        closet: PrototypeClosetStore? = nil,
        outfits: PrototypeOutfitStore,
        onSignOut: @escaping () -> Void,
        image: @escaping (ClothingItem) -> Image = {
            _ in Image(systemName: "photo")
        },
        uiImage: ((ClothingItem) -> UIImage?)? = nil,
        
    ) {
        self.username = username
        self.items = items
        self.model = model
        self.closet = closet
        _outfits = ObservedObject(wrappedValue: outfits)
        self.onSignOut = onSignOut
        self.image = image
        self.uiImage = uiImage
    }

    var body: some View {
        NavigationStack {
            AvatarStudioView(
                model: model,
                closet: closet,
                items: items,
                outfits: outfits,
                image: image,
                uiImage: uiImage,
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView(
        username: "aditya",
        items: ClothingItem.previewSamples,
        model: OutfitStudioModel(),
        outfits: PrototypeOutfitStore(ownerId: "preview"),
        onSignOut: {}
    )
}
