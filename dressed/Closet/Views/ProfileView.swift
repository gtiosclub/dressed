import Combine
import SwiftUI

struct SavedOutfit: Identifiable {
    let id = UUID()
    var name: String
    var worn: [ClothingCategory: ClothingItem]
}

nonisolated final class OutfitStudioModel: ObservableObject {
    @Published var look: [AvatarPart: Int] {
        didSet { saveLook() }
    }
    @Published var worn: [ClothingCategory: ClothingItem] = [:] {
        didSet { recordWornChange() }
    }
    @Published var savedOutfits: [SavedOutfit] = []
    @Published var zoom: Double = 1
    @Published private(set) var lookSaveError: String?

    // Undo/redo for clothing selections. `worn` is changed from many places, so its didSet records
    // each change. In-memory only, like `worn` itself.
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    private var history = UndoHistory(initial: OutfitSnapshot())
    private var isRestoring = false

    // nil for previews, which should not read or write anyone's saved avatar.
    private let ownerId: String?

    init(ownerId: String? = nil) {
        self.ownerId = ownerId
        look = ownerId.map(AvatarLookStore.load(ownerId:)) ?? [:]
    }

    private func recordWornChange() {
        guard !isRestoring else { return }
        history.commit(OutfitSnapshot(worn))
        refreshHistoryFlags()
    }

    private func refreshHistoryFlags() {
        canUndo = history.canUndo
        canRedo = history.canRedo
    }

    /// Goes back one clothing change. `available` is the set of closet item ids that still exist; pieces
    /// outside it are left off. Does nothing when there is nothing to undo.
    func undo(available: Set<String>? = nil) {
        step(available: available, direction: .undo)
    }

    /// Redoes the clothing change that was just undone. See `undo(available:)`.
    func redo(available: Set<String>? = nil) {
        step(available: available, direction: .redo)
    }

    private enum HistoryDirection { case undo, redo }

    private func step(available: Set<String>?, direction: HistoryDirection) {
        let before = OutfitSnapshot(worn)
        while let snapshot = direction == .undo ? history.undo() : history.redo() {
            let applied = available.map { snapshot.keeping(only: $0) } ?? snapshot
            // A step whose only change was a piece that no longer exists looks like nothing happened, so skip it.
            if applied == before { continue }
            isRestoring = true
            worn = applied.items
            isRestoring = false
            history.replacePresent(with: applied)
            break
        }
        refreshHistoryFlags()
    }

    func clearLookSaveError() {
        lookSaveError = nil
    }

    private func saveLook() {
        guard let ownerId else { return }
        do {
            try AvatarLookStore.save(look, ownerId: ownerId)
            lookSaveError = nil
        } catch {
            lookSaveError = "Your avatar changes could not be saved: \(error.localizedDescription)"
        }
    }

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
    @Environment(\.dismiss) private var dismiss
    @State private var showsStudio = false
    let username: String
    let items: [ClothingItem]
    @ObservedObject var model: OutfitStudioModel
    @ObservedObject var outfits: PrototypeOutfitStore
    let openStudioOnPresent: Bool

    var closet: PrototypeClosetStore?

    let image: (ClothingItem) -> Image
    let onSignOut: () -> Void

    let uiImage: ((ClothingItem) -> UIImage?)?

    init(
        username: String,
        items: [ClothingItem],
        model: OutfitStudioModel,
        closet: PrototypeClosetStore? = nil,
        outfits: PrototypeOutfitStore,
        openStudioOnPresent: Bool = false,
        onSignOut: @escaping () -> Void,
        image: @escaping (ClothingItem) -> Image = {
            _ in Image(systemName: "photo")
        },
        uiImage: ((ClothingItem) -> UIImage?)? = nil,

    ) {
        self.username = username
        self.items = items
        _model = ObservedObject(wrappedValue: model)
        self.closet = closet
        _outfits = ObservedObject(wrappedValue: outfits)
        self.openStudioOnPresent = openStudioOnPresent
        _showsStudio = State(initialValue: openStudioOnPresent)
        self.onSignOut = onSignOut
        self.image = image
        self.uiImage = uiImage
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 72))
                    .accessibilityHidden(true)
                Text(username).font(.title2.weight(.semibold))
                Button("Open studio") { showsStudio = true }
                    .buttonStyle(.borderedProminent)
                Button("Sign Out", action: onSignOut)
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(isPresented: $showsStudio) {
                AvatarStudioView(
                    model: model,
                    closet: closet,
                    items: items,
                    outfits: outfits,
                    image: image,
                    uiImage: uiImage
                )
            }
        }
        .alert(
            "Avatar not saved",
            isPresented: Binding(
                get: { model.lookSaveError != nil },
                set: { if !$0 { model.clearLookSaveError() } }
            )
        ) {
            Button("OK", role: .cancel) { model.clearLookSaveError() }
        } message: {
            Text(model.lookSaveError ?? "Please try again.")
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
