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
    @State private var pendingSharedImage: ReviewImage?
    @State private var presentedSharedId: String?
    @State private var deferredSharedId: String?

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
                .toolbar { signOutToolbar }
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
