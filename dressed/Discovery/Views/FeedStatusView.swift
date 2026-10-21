//
//  FeedStatusView.swift
//  dressed
//
//  Created by Sparsh Jain on 10/13/26.
//

import SwiftUI

struct FeedStatusView: View {

    /// The state the parent wants displayed.
    enum Status: Equatable {
        case loading
        case empty
        case error(message: String)
    }

    let status: Status
    /// Called once per Retry tap (error state only).
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(spacing: 16) {
            switch status {
            case .loading:
                ProgressView()
                    .controlSize(.large)
                    .accessibilityIdentifier("feedStatus.loading")

            case .empty:
                Text("No posts yet")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("feedStatus.empty")

            case .error(let message):
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("feedStatus.errorMessage")

                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("feedStatus.retry")
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Previews

#Preview("Loading") {
    FeedStatusView(status: .loading)
}

#Preview("Empty") {
    FeedStatusView(status: .empty)
}

#Preview("Error") {
    FeedStatusView(status: .error(message: "Could not load posts")) {
        print("Retry tapped")
    }
}
