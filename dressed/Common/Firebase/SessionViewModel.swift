import Combine
import FirebaseAuth
import Foundation

@MainActor
protocol SessionService {
    func observe(_ onChange: @escaping (String?) -> Void) -> () -> Void
    func signIn(email: String, password: String) async throws
    func createAccount(email: String, password: String) async throws
    func signOut() throws
}

@MainActor
final class FirebaseSessionService: SessionService {
    func observe(_ onChange: @escaping (String?) -> Void) -> () -> Void {
        let auth = Auth.auth()
        let handle = auth.addStateDidChangeListener { _, user in
            let userId = user?.uid
            Task { @MainActor in onChange(userId) }
        }
        return { auth.removeStateDidChangeListener(handle) }
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func createAccount(email: String, password: String) async throws {
        _ = try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}

@MainActor
final class SessionViewModel: ObservableObject {
    enum State: Equatable {
        case checking
        case signedOut
        case signedIn(String)
    }

    @Published private(set) var state: State = .checking
    private let service: SessionService
    private var stopObserving: (() -> Void)?

    init(service: SessionService) {
        self.service = service
        stopObserving = service.observe { [weak self] userId in
            self?.state = userId.map(State.signedIn) ?? .signedOut
        }
    }

    func signIn(email: String, password: String) async throws {
        try await service.signIn(email: email, password: password)
    }

    func createAccount(email: String, password: String) async throws {
        try await service.createAccount(email: email, password: password)
    }

    func signOut() throws {
        try service.signOut()
        state = .signedOut
    }

    deinit {
        stopObserving?()
    }
}

@MainActor
final class PreviewSessionService: SessionService {
    private var userId: String?
    private var onChange: ((String?) -> Void)?

    init(userId: String?) {
        self.userId = userId
    }

    func observe(_ onChange: @escaping (String?) -> Void) -> () -> Void {
        self.onChange = onChange
        onChange(userId)
        return { [weak self] in self?.onChange = nil }
    }

    func signIn(email: String, password: String) async throws {
        userId = "preview_user"
        onChange?(userId)
    }

    func createAccount(email: String, password: String) async throws {
        try await signIn(email: email, password: password)
    }

    func signOut() throws {
        userId = nil
        onChange?(nil)
    }
}
