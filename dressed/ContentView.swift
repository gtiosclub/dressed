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
    // Shared by the My Closet and Avatar tabs so saved outfits show up in both.
    @State private var studio = OutfitStudioModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ClothingItemsList(
                    items: ClothingItem.previewSamples,
                    outfits: studio.savedOutfits,
                    onSelect: { _ in
                        // open item detail later
                    },
                    onSelectOutfit: { id in
                        studio.wearOutfit(id: id)
                        selectedTab = 3  // jump to the Avatar tab wearing that outfit
                    }
                )
                .navigationTitle("My Closet")
                .navigationBarTitleDisplayMode(.inline)
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

            // OutfitStudioView has its own NavigationStack, so it is not wrapped in another one.
            OutfitStudioView(items: ClothingItem.previewSamples, model: studio)  // swap for real items later
                .tabItem { Label("Avatar", systemImage: "figure.stand") }
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
            Button("Sign Out") {
                do {
                    try session.signOut()
                    SharedImageInbox.setActiveOwner(nil)
                } catch {
                    signOutError = error.localizedDescription
                }
            }
        }
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
