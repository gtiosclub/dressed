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
                AppTabs(session: session)
                    .id(userId)
            }
        }
    }
}

private struct AppTabs: View {
    @ObservedObject var session: SessionViewModel
    @State private var selectedTab = 0
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
                    },
                    onEditOutfit: { id in
                        studio.beginEditingOutfit(id: id, shouldOpenTryOn: true)
                        selectedTab = 3
                    },
                    onDeleteOutfit: { id in
                        studio.removeOutfit(id: id)
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

                    ContentUnavailableView(
                        discoverySection == 0 ? "No posts yet" : "Search is coming soon",
                        systemImage: discoverySection == 0 ? "person.2" : "magnifyingglass",
                        description: Text(discoverySection == 0
                            ? "Outfit posts will appear here."
                            : "Find clothing and outfits here later.")
                    )
                }
                .navigationTitle("Discovery")
            }
            .tabItem { Label("Discovery", systemImage: "safari") }
            .tag(1)

            NavigationStack {
                ContentUnavailableView(
                    "Import is coming soon",
                    systemImage: "camera",
                    description: Text("Photo selection and capture will appear here.")
                )
                .navigationTitle("Camera")
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
    }

    @ToolbarContentBuilder
    private var signOutToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Sign Out") {
                do {
                    try session.signOut()
                } catch {
                    signOutError = error.localizedDescription
                }
            }
        }
    }
}

#Preview("Signed out") {
    ContentView(session: SessionViewModel(service: PreviewSessionService(userId: nil)))
}

#Preview("Signed in") {
    ContentView(session: SessionViewModel(service: PreviewSessionService(userId: "preview_user")))
}
