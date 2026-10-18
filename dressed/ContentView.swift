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
    @State private var dismissDiscoverySearchRequest = 0
    @State private var signOutError: String?
    @State private var showingProfile = false
    @State private var pendingSharedImage: ReviewImage?
    @State private var presentedSharedId: String?
    @State private var deferredSharedId: String?
    @State private var sharedImageError: String?
    @State private var pendingSharedLink: ReviewProductLink?
    @State private var presentedSharedLinkId: String?
    @State private var deferredSharedLinkId: String?
    @State private var studio = OutfitStudioModel()

    init(session: SessionViewModel, userId: String) {
        self.session = session
        self.userId = userId
        _closet = StateObject(wrappedValue: PrototypeClosetStore(ownerId: userId))
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        _selectedTab = State(initialValue: arguments.contains("-showCamera") ? 2 :
            (arguments.contains("-showCatalog") || arguments.contains("-showDiscovery") ? 1 : 0))
        _discoverySection = State(initialValue: arguments.contains("-showCatalog") ? 1 : 0)
        #else
        _selectedTab = State(initialValue: 0)
        #endif
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                PrototypeClosetView(closet: closet)
                .toolbar { profileToolbar }
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
                        DiscoveryFeedView(dismissRequest: dismissDiscoverySearchRequest)
                    } else {
                        PrototypeCatalogView()
                    }
                }
                .background {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { dismissDiscoverySearchRequest &+= 1 }
                }
                .navigationTitle("Discovery")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { profileToolbar }
            }
            .tabItem { Label("Discovery", systemImage: "safari") }
            .tag(1)

            NavigationStack {
                PrototypeImportView(closet: closet, ownerId: userId)
                    .toolbar {
                        profileToolbar
                        if deferredSharedId != nil || deferredSharedLinkId != nil {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Review Share") {
                                    deferredSharedId = nil
                                    deferredSharedLinkId = nil
                                    presentNextShare()
                                }
                            }
                        }
                    }
            }
            .tabItem { Label("Camera", systemImage: "camera") }
            .tag(2)

            ProfileView(
                username: userId,
                items: closet.items,
                model: studio,
                onSignOut: signOut,
                image: { photo(for: $0) },
                uiImage: { closet.image(for: $0) }
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
        .sheet(isPresented: $showingProfile) {
            NavigationStack {
                List {
                    Section {
                        Label("Signed in to Dressed", systemImage: "person.crop.circle.fill")
                    }
                    Section {
                        Button("Sign Out", role: .destructive, action: signOut)
                            .accessibilityIdentifier("profile.signOut")
                    }
                }
                .navigationTitle("Profile")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showingProfile = false }
                    }
                }
            }
        }
        .alert("Shared image unavailable", isPresented: Binding(
            get: { sharedImageError != nil },
            set: { if !$0 { sharedImageError = nil } }
        )) {
            Button("OK") {
                sharedImageError = nil
                presentNextShare()
            }
        } message: {
            Text(sharedImageError ?? "Please share the image again.")
        }
        .sheet(item: $pendingSharedImage, onDismiss: {
            if let presentedSharedId {
                deferredSharedId = presentedSharedId
                self.presentedSharedId = nil
            } else {
                presentNextShare()
            }
        }) { image in
            SharedImportReviewView(
                image: image,
                ownerId: userId,
                closet: closet,
                onLater: {
                    deferredSharedId = image.id
                    pendingSharedImage = nil
                },
                onDiscard: {
                    SharedImageInbox.remove(id: image.id)
                    presentedSharedId = nil
                    deferredSharedId = nil
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
        .sheet(item: $pendingSharedLink, onDismiss: {
            if let presentedSharedLinkId {
                deferredSharedLinkId = presentedSharedLinkId
                self.presentedSharedLinkId = nil
            } else {
                presentNextShare()
            }
        }) { link in
            ProductLinkReviewView(link: link, ownerId: userId,
                                  onLater: {
                                      deferredSharedLinkId = link.id
                                      pendingSharedLink = nil
                                  },
                                  onSaved: {
                                      SharedProductLinkInbox.remove(id: link.id)
                                      presentedSharedLinkId = nil
                                      deferredSharedLinkId = nil
                                      pendingSharedLink = nil
                                  })
        }
        .onAppear {
            SharedImageInbox.setActiveOwner(userId)
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if let marker = arguments.firstIndex(of: "-seedShareFixture"),
               arguments.indices.contains(marker + 1) {
                do {
                    try SharedImageInbox.seedFixture(
                        id: arguments[marker + 1], ownerId: userId,
                        withCandidates: arguments.contains("-seedTwoCandidates")
                    )
                } catch {
                    sharedImageError = error.localizedDescription
                }
            }
            #endif
            presentNextShare()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { presentNextShare() }
        }
    }

    @ToolbarContentBuilder
    private var profileToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingProfile = true
            } label: {
                Image(systemName: "person.crop.circle")
            }
            .accessibilityLabel("Profile")
            .accessibilityIdentifier("app.profileButton")
        }
    }

    private func signOut() {
        showingProfile = false
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

    private func presentNextShare() {
        guard pendingSharedImage == nil, presentedSharedId == nil,
              deferredSharedId == nil, sharedImageError == nil,
              pendingSharedLink == nil, presentedSharedLinkId == nil,
              deferredSharedLinkId == nil else { return }
        switch SharedImageInbox.next(for: userId) {
        case .image(let image):
            presentedSharedId = image.id
            selectedTab = 2
            pendingSharedImage = image
        case .discarded(let message):
            selectedTab = 2
            sharedImageError = message
        case .none:
            switch SharedProductLinkInbox.next(for: userId) {
            case .link(let link):
                presentedSharedLinkId = link.id
                selectedTab = 2
                pendingSharedLink = link
            case .discarded(let message):
                selectedTab = 2
                sharedImageError = message
            case .none:
                break
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
