//
//  SavePostToggle.swift
//  dressed
//
//  Created by Henrick Ngo on 10/16/26.
//

import SwiftUI

// SOCIAL-13 (#149): Save control for one post. Shows the parent's saved state and reports the
// requested change; the parent makes the Firestore save (#61) or remove (#121) call.
struct SavePostToggle: View {
    let postId: String
    let isSaved: Bool
    // True while the parent completes a request; the control is disabled until it clears.
    let isWorking: Bool
    // Reports the post ID and the desired saved state, once per tap.
    let onToggle: (_ postId: String, _ isSaved: Bool) -> Void

    var body: some View {
        Button {
            guard !isWorking else { return }
            onToggle(postId, !isSaved)
        } label: {
            Label {
                Text(isSaved ? "Saved" : "Save")
            } icon: {
                if isWorking {
                    ProgressView()
                } else {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                }
            }
        }
        .buttonStyle(.bordered)
        .disabled(isWorking)
        .accessibilityLabel("Save post")
        .accessibilityValue(isSaved ? "Saved" : "Not saved")
        .accessibilityIdentifier("savePostToggle.button")
    }
}

// MARK: - Previews

#Preview("Not saved") {
    SavePostToggle(postId: "post_001", isSaved: false, isWorking: false) { _, _ in }
        .padding()
}

#Preview("Saved") {
    SavePostToggle(postId: "post_001", isSaved: true, isWorking: false) { _, _ in }
        .padding()
}

#Preview("Working") {
    SavePostToggle(postId: "post_001", isSaved: false, isWorking: true) { _, _ in }
        .padding()
}

// Preview-only parent. It stands in for the Firestore call with a short delay and lists
// every report, so screenshots show one report per tap and none while working.
private struct SavePostTogglePreview: View {
    @State private var isSaved = false
    @State private var isWorking = false
    @State private var reports: [String] = []

    var body: some View {
        VStack(spacing: 16) {
            SavePostToggle(postId: "post_001", isSaved: isSaved, isWorking: isWorking) { postId, save in
                reports.append("(\(postId), \(save))")
                isWorking = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    isSaved = save
                    isWorking = false
                }
            }

            Text("Reports: \(reports.isEmpty ? "none" : reports.joined(separator: ", "))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview("Interactive") {
    SavePostTogglePreview()
}
