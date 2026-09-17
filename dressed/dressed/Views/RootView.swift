//
//  RootView.swift
//  dressed
//

import SwiftUI

/// Sends the user to the auth screen or the main app depending on sign-in state.
struct RootView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        Group {
            if !session.isReady {
                ProgressView()
            } else if !session.isSignedIn {
                Authentication()
            } else {
                HomeView()
            }
        }
        .animation(.default, value: session.isSignedIn)
    }
}

#Preview {
    RootView()
        .environmentObject(SessionStore())
}
