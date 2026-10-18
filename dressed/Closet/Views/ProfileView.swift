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

    // Tapping the worn item again takes it off. Tapping another item in the same category
    // (another top, say) replaces it.
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

// Avatar tab: username + a small version of the current avatar.
// Tapping the avatar opens the studio, where the user can try on closet pieces,
// customize the avatar, and take a picture.
// The model is owned by the parent so the look and worn pieces are shared across tabs.
struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    let username: String
    let items: [ClothingItem]
    let model: OutfitStudioModel
    var closet: PrototypeClosetStore? = nil
    let image: (ClothingItem) -> Image
    let onSignOut: () -> Void

    let uiImage: ((ClothingItem) -> UIImage?)?

    @State private var showsStudio = false

    init(
        username: String,
        items: [ClothingItem],
        model: OutfitStudioModel,
        closet: PrototypeClosetStore? = nil,
        onSignOut: @escaping () -> Void,
        image: @escaping (ClothingItem) -> Image = { _ in Image(systemName: "photo") },
        uiImage: ((ClothingItem) -> UIImage?)? = nil
    ) {
        self.username = username
        self.items = items
        self.model = model
        self.closet = closet
        self.onSignOut = onSignOut
        self.image = image
        self.uiImage = uiImage
    }

    var body: some View {
        NavigationStack {
            ProfileHome(username: username, model: model, image: image, uiImage: uiImage, onSignOut: onSignOut) {
                showsStudio = true
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showsStudio) {
                AvatarStudioView(model: model, closet: closet, items: items, image: image, uiImage: uiImage)
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
    let onOpenStudio: () -> Void

    // The live 3D avatar only exists while this screen is on screen. A pushed screen or another tab
    // keeps this view alive, and a hidden 3D scene still holds a GPU drawable.
    @State private var isVisible = true

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Button(action: onOpenStudio) {
                    avatarCard
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
                .accessibilityLabel("Open avatar studio")

                Text(username).font(.title2.bold())

                Button("Open studio", action: onOpenStudio)
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
                    .accessibilityIdentifier("profile.signOut")
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    @ViewBuilder
    private var avatarCard: some View {
        if isVisible {
            // Fixed zoom so the small avatar doesn't inherit the studio's zoom slider.
            AvatarView(
                look: model.look,
                worn: model.worn,
                image: image,
                uiImage: uiImage,
                zoom: 1,
                allowsInteraction: false
            )
            .allowsHitTesting(false)   // the button handles taps, not the spin gesture
        } else {
            ZStack {
                LinearGradient(colors: [Color(white: 0.97), Color(white: 0.88)], startPoint: .top, endPoint: .bottom)
                Image(systemName: AvatarGender(look: model.look).symbol)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(white: 0.75))
                    .padding(28)
            }
        }
    }
}

#Preview {
    ProfileView(username: "aditya", items: ClothingItem.previewSamples, model: OutfitStudioModel(), onSignOut: {})
}
