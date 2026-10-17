import SwiftUI

struct ContentView: View {
    @StateObject private var session: SessionViewModel

    init(session: SessionViewModel) {
        _session = StateObject(wrappedValue: session)
    }

    var body: some View {
        Group {
            switch session.state {
            case .checking:
                ProgressView("Checking your session…")
            case .signedOut:
                Authentication(session: session)
            case .signedIn(let userId):
                AppTabs(session: session, userId: userId)
                    .id(userId)
            }
        }
    }
}

private struct AppTabs: View {
    @ObservedObject var session: SessionViewModel
    let userId: String
    @StateObject private var closet: PrototypeClosetStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab: Int
    @State private var discoverySection = 0
    @State private var signOutError: String?
    @State private var pendingSharedImage: ReviewImage?
    @State private var presentedSharedId: String?
    @State private var deferredSharedId: String?
    @State private var selectedItemId: String?
    // Shared by the My Closet and Profile tabs so saved outfits show up in both.
    @State private var studio = OutfitStudioModel()

    // TODO: swap in the real display name once the session exposes one (e.g. session.username).
    private var username: String { userId }

    init(session: SessionViewModel, userId: String) {
        self.session = session
        self.userId = userId
        _closet = StateObject(wrappedValue: PrototypeClosetStore(ownerId: userId))
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        _selectedTab = State(initialValue: arguments.contains("-showCamera") ? 2 :
            (arguments.contains("-showCatalog") ? 1 : 0))
        _discoverySection = State(initialValue: arguments.contains("-showCatalog") ? 1 : 0)
        #else
        _selectedTab = State(initialValue: 0)
        #endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ClothingItemsList(
                    items: closet.items,
                    outfits: studio.savedOutfits,
                    image: { photo(for: $0) },
                    onSelect: { selectedItemId = $0 },
                    onSelectOutfit: { id in
                        studio.wearOutfit(id: id)
                        selectedTab = 3  // jump to the Profile tab wearing that outfit
                    }
                )
                .navigationTitle("My Closet")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $selectedItemId) { id in
                    PrototypeItemDetailView(closet: closet, itemID: id)
                }
                .toolbar { signOutToolbar }
                .onAppear { closet.reload() }
            }
            .tabItem { Label("My Closet", systemImage: "hanger") }
            .tag(0)

            NavigationStack {
                VStack {
                    Picker("Discovery", selection: $discoverySection) {
                        Text("Feed").tag(0)
                        Text("Search").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if discoverySection == 0 {
                        ContentUnavailableView(
                            "No posts yet",
                            systemImage: "person.2",
                            description: Text("Outfit posts will appear here.")
                        )
                    } else {
                        PrototypeCatalogView()
                    }
                }
                .navigationTitle("Discovery")
            }
            .tabItem { Label("Discovery", systemImage: "safari") }
            .tag(1)

            NavigationStack {
                PrototypeImportView(closet: closet)
                    .toolbar {
                        if deferredSharedId != nil {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Review Share") {
                                    deferredSharedId = nil
                                    presentNextSharedImage()
                                }
                            }
                        }
                    }
            }
            .tabItem { Label("Camera", systemImage: "camera") }
            .tag(2)

            // ProfileView has its own NavigationStack (it also hosts the avatar studio flow),
            // so it is not wrapped in another one.
            ProfileView(
                username: username,
                items: closet.items,
                model: studio,
                onSignOut: signOut,
                image: { photo(for: $0) }
            )
            .tabItem { Label("Profile", systemImage: "person.crop.circle") }
            .tag(3)
        }
        .alert("Could not sign out", isPresented: Binding(
            get: { signOutError != nil },
            set: { if !$0 { signOutError = nil } }
        )) {
            Button("OK", role: .cancel) { signOutError = nil }
        } message: {
            Text(signOutError ?? "Please try again.")
        }
        .sheet(item: $pendingSharedImage, onDismiss: {
            if let presentedSharedId {
                deferredSharedId = presentedSharedId
                self.presentedSharedId = nil
            } else {
                presentNextSharedImage()
            }
        }) { image in
            ImportReviewView(
                image: image,
                closet: closet,
                onCancel: {
                    deferredSharedId = image.id
                    pendingSharedImage = nil
                },
                onSaved: {
                    SharedImageInbox.remove(id: image.id)
                    presentedSharedId = nil
                    deferredSharedId = nil
                    pendingSharedImage = nil
                }
            )
        }
        .onAppear {
            SharedImageInbox.setActiveOwner(userId)
            presentNextSharedImage()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { presentNextSharedImage() }
        }
    }

    @ToolbarContentBuilder
    private var signOutToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Sign Out", action: signOut)
        }
    }

    private func signOut() {
        do {
            try session.signOut()
            SharedImageInbox.setActiveOwner(nil)
        } catch {
            signOutError = error.localizedDescription
        }
    }

    private func photo(for item: ClothingItem) -> Image {
        closet.image(for: item).map { Image(uiImage: $0) } ?? Image(systemName: "photo")
    }

    private func presentNextSharedImage() {
        guard pendingSharedImage == nil, presentedSharedId == nil, deferredSharedId == nil,
              let image = SharedImageInbox.next(for: userId) else { return }
        presentedSharedId = image.id
        selectedTab = 2
        pendingSharedImage = image
    }
}

#Preview("Signed out") {
    ContentView(session: SessionViewModel(service: PreviewSessionService(userId: nil)))
}

#Preview("Signed in") {
    ContentView(session: SessionViewModel(service: PreviewSessionService(userId: "preview_user")))
}
