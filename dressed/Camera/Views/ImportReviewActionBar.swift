//
//  ImportReviewActionBar.swift
//  dressed
//
//  Created by Riva Patel on 10/13/26.
//

import SwiftUI

// Selection and saving belong to the parent review screen.
struct ImportReviewActionBar: View {
    let selectedCount: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(selectedCount) selected")
                .font(.subheadline)

            Spacer()

            Button("Cancel", action: onCancel)
                .buttonStyle(.bordered)

            Button("Confirm") {
                guard selectedCount > 0 else { return }
                onConfirm()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedCount <= 0)
        }
        .padding()
    }
}

#Preview("Zero selected") {
    ImportReviewActionBar(
        selectedCount: 0,
        onConfirm: {},
        onCancel: {}
    )
}

#Preview("Two selected") {
    ImportReviewActionBar(
        selectedCount: 2,
        onConfirm: {},
        onCancel: {}
    )
}
