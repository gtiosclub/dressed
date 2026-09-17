//
//  SessionStore.swift
//  dressed
//

import Combine
import FirebaseAuth
import SwiftUI

/// Tracks the signed-in Firebase user so views can react to sign in / sign out.
@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var isReady = false

    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                self?.isReady = true
            }
        }
    }

    deinit {
        if let listener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    var isSignedIn: Bool { user != nil }

    var displayName: String {
        user?.email?.components(separatedBy: "@").first?.capitalized ?? "there"
    }

    func signOut() {
        try? Auth.auth().signOut()
    }
}
