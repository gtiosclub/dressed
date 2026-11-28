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
    @StateObject private var postLikes: PostLikesViewModel
    @StateObject private var profile: MyProfileModel
    @StateObject private var userProfiles: UserProfileStore
    @StateObject private var follows: FollowViewModel
    @StateObject private var moderation: ModerationViewModel

    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: Int
    @State private var tabBeforeCamera = 0
    @State private var isKeyboardVisible = false
    @State private var isCreatingPost = false
    @State private var discoverySection = 0
    @State private var isSearchingDiscovery = false
    @State private var isShowingProfile = false
    @State private var selectedAuthorId: String?
    @State private var deletedPostIds: Set<String> = []
    @State private var isSearchingCloset = false
    @State private var closetSearchText = ""
    @State private var discoverySearchQuery: String?
    @State private var signOutError: String?
    @State private var pendingSharedImage: ReviewImage?
    @State private var presentedSharedId: String?
    @State private var deferredSharedId: String?
    @State private var sharedImageError: String?

    @State private var pendingSharedLink: ReviewProductLink?
    @State private var presentedSharedLinkId: String?
    @State private var deferredSharedLinkId: String?

    @StateObject private var studio: OutfitStudioModel
    @StateObject private var outfits: PrototypeOutfitStore

    init(session: SessionViewModel, userId: String) {
        self.session = session
        self.userId = userId
        _studio = StateObject(wrappedValue: OutfitStudioModel(ownerId: userId))
        _outfits = StateObject(wrappedValue: PrototypeOutfitStore(ownerId: userId))

        _closet = StateObject(
            wrappedValue: PrototypeClosetStore(ownerId: userId)
        )
        _postLikes = StateObject(wrappedValue: PostLikesViewModel(
            ownerId: userId,
            service: DiscoveryPostSource.currentPostLikes
        ))
        _profile = StateObject(wrappedValue: MyProfileModel(ownerId: userId, service: DiscoveryPostSource.current))
        _userProfiles = StateObject(wrappedValue: UserProfileStore(service: DiscoveryPostSource.currentUserProfiles))
        _follows = StateObject(wrappedValue: FollowViewModel(ownerId: userId, service: DiscoveryPostSource.currentFollows))
        _moderation = StateObject(wrappedValue: ModerationViewModel(ownerId: userId, service: DiscoveryPostSource.currentModeration))

        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        _selectedTab = State(initialValue: arguments.contains("-showCamera") ? 2 :
            (arguments.contains("-showCatalog") || arguments.contains("-showDiscovery") ? 1 : 0))
        _discoverySection = State(initialValue: arguments.contains("-showOOTD") ? 1 : 0)
        #else
        _selectedTab = State(initialValue: 0)
        #endif
    }

    private var postCompositionSource: any PostCompositionSource {
        LocalPostCompositionSource(ownerId: userId, closet: closet, outfits: outfits)
    }

    @ViewBuilder private var ootdFeed: some View {
        let categories = closet.items.map(\.category)
        let openProfile: (String) -> Void = { authorId in
            if authorId == userId {
                isShowingProfile = true
            } else {
                selectedAuthorId = authorId
            }
        }
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if DiscoveryPostSource.isDemo {
            InfiniteDiscoveryFeed.demo(
                failSecondPage: arguments.contains("-failDiscoveryPage"),
                authorId: userId,
                section: $discoverySection,
                showingCreate: $isCreatingPost,
                isSearching: $isSearchingDiscovery,
                compositionSource: postCompositionSource,
                postLikes: postLikes,
                userProfiles: userProfiles,
                follows: follows,
                moderation: moderation,
                closetCategories: categories,
                deletedPostIds: $deletedPostIds,
                onOpenProfile: openProfile
            )
        } else {
            InfiniteDiscoveryFeed.live(
                authorId: userId,
                section: $discoverySection,
                showingCreate: $isCreatingPost,
                isSearching: $isSearchingDiscovery,
                compositionSource: postCompositionSource,
                postLikes: postLikes,
                userProfiles: userProfiles,
                follows: follows,
                moderation: moderation,
                closetCategories: categories,
                deletedPostIds: $deletedPostIds,
                onOpenProfile: openProfile
            )
        }
        #else
        InfiniteDiscoveryFeed.live(
            authorId: userId,
            section: $discoverySection,
            showingCreate: $isCreatingPost,
            isSearching: $isSearchingDiscovery,
            compositionSource: postCompositionSource,
            postLikes: postLikes,
            userProfiles: userProfiles,
            follows: follows,
            moderation: moderation,
            closetCategories: categories,
            deletedPostIds: $deletedPostIds,
            onOpenProfile: openProfile
        )
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
                        outfits: outfits,
                        ownerId: userId,
                        isSearching: $isSearchingCloset,
                        searchText: $closetSearchText,
                        onTryOn: { item in
                            studio.worn[item.category] = item
                            selectedTab = 3
                        },
                        onTryOutfit: { outfit in
                            var worn: [ClothingCategory: ClothingItem] = [:]
                            for placement in outfit.placements {
                                if let item = closet.item(id: placement.itemId) { worn[item.category] = item }
                            }
                            studio.worn = worn
                            selectedTab = 3
                        }
                    )
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(0)

                // MARK: - Discovery

                NavigationStack {
                    VStack(spacing: 0) {
                        DiscoveryHeader(
                            section: $discoverySection,
                            profileInitial: profileInitial(userProfiles.profile(for: userId)?.displayName ?? session.accountName),
                            onProfile: { isShowingProfile = true },
                            onCreatePost: {
                                discoverySection = 1
                                isCreatingPost = true
                            }
                        )

                        ootdFeed
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    // Hide on the navigation content too, so the system bar cannot intercept feed taps.
                    .toolbar(.hidden, for: .tabBar)
                    .navigationDestination(item: $discoverySearchQuery) { query in
                        DiscoveryIdeasView(initialQuery: query)
                    }
                    .navigationDestination(isPresented: $isShowingProfile) {
                        MyProfileView(
                            name: session.accountName,
                            pieceCount: closet.items.count,
                            outfitCount: outfits.outfits.count,
                            model: profile,
                            onSignOut: signOut,
                            ownerId: userId,
                            userProfiles: userProfiles,
                            follows: follows,
                            onDeletePost: { post in
                                try await DiscoveryPostSource.current.deletePost(id: post.id)
                                deletedPostIds.insert(post.id)
                            }
                        )
                    }
                    .navigationDestination(item: $selectedAuthorId) { authorId in
                        AuthorProfileView(
                            authorId: authorId,
                            currentUserId: userId,
                            userProfiles: userProfiles,
                            follows: follows,
                            moderation: moderation
                        )
                    }
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(1)

                // MARK: - Camera

                NavigationStack {
                    PrototypeImportView(
                        closet: closet,
                        ownerId: userId,
                        onClose: { selectedTab = tabBeforeCamera },
                        onReviewShare: deferredSharedId != nil || deferredSharedLinkId != nil ? {
                            deferredSharedId = nil
                            deferredSharedLinkId = nil
                            presentNextShare()
                        } : nil,
                        onReviewImage: { image in
                            guard pendingSharedImage == nil, pendingSharedLink == nil else { return }
                            presentedSharedId = image.id
                            pendingSharedImage = image
                        }
                    )
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
                        outfits: outfits,
                        onSignOut: signOut,
                        image: { photo(for: $0) },
                        uiImage: { closet.image(for: $0) }
                    )
                }
                .toolbar(.hidden, for: .tabBar)
                .tag(3)
            }
            // Hidden while typing, like the system tab bar.
            // The camera is full screen: its close button returns to the previous tab.
            if !isKeyboardVisible && selectedTab != 2 {
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
        .overlay {
            // Covers the whole screen, header and tab bar included, like the Figma open state.
            if isSearchingDiscovery {
                DiscoverySearchOverlay(
                    onSearch: { query in
                        isSearchingDiscovery = false
                        discoverySearchQuery = query
                    },
                    onClose: { isSearchingDiscovery = false }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if isSearchingCloset {
                ClosetSearchOverlay(
                    initialQuery: closetSearchText,
                    names: closet.items.map(\.name) + outfits.outfits.compactMap(\.name),
                    onSearch: { query in
                        closetSearchText = query
                        isSearchingCloset = false
                    },
                    onClose: { isSearchingCloset = false }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isSearchingDiscovery)
        .animation(.easeOut(duration: 0.2), value: isSearchingCloset)
        #if DEBUG
        .task { DemoClosetSeeder.seedIfNeeded(closet: closet, outfits: outfits) }
        #endif
        .task {
            await userProfiles.ensureOwnProfile(userId: userId, accountName: session.accountName)
            await follows.loadFollowing()
            await moderation.loadBlockedUsers()
        }
        .onChange(of: selectedTab) { old, new in
            if new == 2 && old != 2 { tabBeforeCamera = old }
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

        .fullScreenCover(
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
                recognizer: sharedRecognitionService,
                matcher: productMatcher,
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

            if arguments.contains("-importDemo") {
                do { try SharedImageInbox.seedDemoPhoto(ownerId: userId) }
                catch { sharedImageError = error.localizedDescription }
            }

            // Reviews a photo from this Mac, for simulator checks with real images.
            if let marker = arguments.firstIndex(of: "-importPhoto"),
               arguments.indices.contains(marker + 1) {
                do {
                    let data = try Data(contentsOf: URL(fileURLWithPath: arguments[marker + 1]))
                    _ = try SharedImageInbox.enqueue(imageData: data, ownerId: userId, source: "Debug photo")
                } catch {
                    sharedImageError = error.localizedDescription
                }
            }

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
                        ),
                        interruptedManual: arguments.contains("-seedInterruptedManual")
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

    private var sharedRecognitionService: any GarmentRecognitionService {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-delaySharedRecognition") {
            return DelayedImportRecognitionTestService()
        }
        #endif
        return OnDeviceImportRecognitionService()
    }


    private var productMatcher: any ProductMatching {
        #if DEBUG
        // Fixture-backed import tests isolate review behavior from catalog matches unless they opt in.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-mockSignedIn") && !arguments.contains("-demoMatches") {
            return NoProductMatches()
        }
        #endif
        if let indexed = CatalogIndexMatcher.configured { return indexed }
        return CatalogVisualMatcher.shared
    }

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
