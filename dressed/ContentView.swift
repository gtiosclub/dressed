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
    @State private var isKeyboardVisible = false
    @State private var isCreatingPost = false
    @State private var discoverySection = 0
    @State private var signOutError: String?
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

        _closet = StateObject(
            wrappedValue: PrototypeClosetStore(ownerId: userId)
        )

        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        _selectedTab = State(initialValue: arguments.contains("-showCamera") ? 2 :
            (arguments.contains("-showCatalog") || arguments.contains("-showDiscovery") ? 1 : 0))
        _discoverySection = State(initialValue: arguments.contains("-showOOTD") ? 1 : 0)
        #else
        _selectedTab = State(initialValue: 0)
        #endif
    }

    var body: some View {
        // The system tab bar is hidden; DSTabBar sits below the tabs so their content ends above it.
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {

                // MARK: - My Closet

                NavigationStack {
                    PrototypeClosetView(
                        closet: closet,
                        ownerId: userId
                    )
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(0)

                // MARK: - Discovery

                NavigationStack {
                    VStack(spacing: 0) {
                        DiscoveryHeader(
                            section: $discoverySection,
                            onProfile: { selectedTab = 3 },
                            onCreatePost: {
                                discoverySection = 1
                                isCreatingPost = true
                            }
                        )

                        if discoverySection == 0 {
                            DiscoveryIdeasView()
                        } else {
                            OOTDFeedView(showingCreate: $isCreatingPost)
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(1)

                // MARK: - Camera

                NavigationStack {
                    PrototypeImportView(
                        closet: closet,
                        ownerId: userId
                    )
                    .toolbar {
                        if deferredSharedId != nil ||
                            deferredSharedLinkId != nil {
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
                .toolbar(.hidden, for: .tabBar)
                .tag(2)

                // MARK: - Avatar

                NavigationStack {
                    ProfileView(
                        username: userId,
                        items: closet.items,
                        model: studio,
                        closet: closet,
                        onSignOut: signOut,
                        image: { photo(for: $0) },
                        uiImage: { closet.image(for: $0) }
                    )
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(3)
            }
            // Hidden while typing, like the system tab bar.
            if !isKeyboardVisible {
                DSTabBar(
                    items: [
                        .init(tag: 0, title: "Closet", icon: "TablerHanger2", accessibilityIdentifier: "tab.closet"),
                        .init(tag: 1, title: "Discovery", icon: "TablerCompass", accessibilityIdentifier: "tab.discovery"),
                        .init(tag: 3, title: "Avatar", icon: "TablerUser", accessibilityIdentifier: "tab.avatar"),
                        .init(tag: 2, title: "Camera", icon: "TablerCamera", accessibilityIdentifier: "tab.camera")
                    ],
                    selection: $selectedTab
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            isKeyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
        }

        // MARK: - Sign Out Error

        .alert(
            "Could not sign out",
            isPresented: Binding(
                get: { signOutError != nil },
                set: {
                    if !$0 {
                        signOutError = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                signOutError = nil
            }
        } message: {
            Text(signOutError ?? "Please try again.")
        }

        // MARK: - Shared Image Error

        .alert(
            "Shared image unavailable",
            isPresented: Binding(
                get: { sharedImageError != nil },
                set: {
                    if !$0 {
                        sharedImageError = nil
                    }
                }
            )
        ) {
            Button("OK") {
                sharedImageError = nil
                presentNextShare()
            }
        } message: {
            Text(sharedImageError ?? "Please share the image again.")
        }

        // MARK: - Shared Image Review

        .sheet(
            item: $pendingSharedImage,
            onDismiss: {
                if let presentedSharedId {
                    deferredSharedId = presentedSharedId
                    self.presentedSharedId = nil
                } else {
                    presentNextShare()
                }
            }
        ) { image in
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

        // MARK: - Shared Product Link Review

        .sheet(
            item: $pendingSharedLink,
            onDismiss: {
                if let presentedSharedLinkId {
                    deferredSharedLinkId = presentedSharedLinkId
                    self.presentedSharedLinkId = nil
                } else {
                    presentNextShare()
                }
            }
        ) { link in
            ProductLinkReviewView(
                link: link,
                ownerId: userId,
                onLater: {
                    deferredSharedLinkId = link.id
                    pendingSharedLink = nil
                },
                onSaved: {
                    SharedProductLinkInbox.remove(id: link.id)
                    presentedSharedLinkId = nil
                    deferredSharedLinkId = nil
                    pendingSharedLink = nil
                }
            )
        }

        // MARK: - Lifecycle

        .onAppear {
            SharedImageInbox.setActiveOwner(userId)

            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments

            if let marker = arguments.firstIndex(
                of: "-seedShareFixture"
            ),
               arguments.indices.contains(marker + 1) {
                do {
                    try SharedImageInbox.seedFixture(
                        id: arguments[marker + 1],
                        ownerId: userId,
                        withCandidates: arguments.contains(
                            "-seedTwoCandidates"
                        )
                    )
                } catch {
                    sharedImageError = error.localizedDescription
                }
            }
            #endif

            presentNextShare()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                presentNextShare()
            }
        }
    }

    // MARK: - Sign Out

    private func signOut() {
        do {
            try session.signOut()
            SharedImageInbox.setActiveOwner(nil)
        } catch {
            signOutError = error.localizedDescription
        }
    }

    // MARK: - Clothing Image

    private func photo(for item: ClothingItem) -> Image {
        closet.image(for: item).map {
            Image(uiImage: $0)
        } ?? Image("TablerPhoto")
    }

    // MARK: - Shared Content Presentation

    private func presentNextShare() {
        guard
            pendingSharedImage == nil,
            presentedSharedId == nil,
            deferredSharedId == nil,
            sharedImageError == nil,
            pendingSharedLink == nil,
            presentedSharedLinkId == nil,
            deferredSharedLinkId == nil
        else {
            return
        }

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

// MARK: - Previews

#Preview("Signed out") {
    ContentView(
        session: SessionViewModel(
            service: PreviewSessionService(userId: nil)
        )
    )
}

#Preview("Signed in") {
    ContentView(
        session: SessionViewModel(
            service: PreviewSessionService(userId: "preview_user")
        )
    )
}
