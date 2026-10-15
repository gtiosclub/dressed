//
//  PostCaptionField.swift
//  dressed
//
//  Created by Daniel  Roldan on 10/13/26.
//

import SwiftUI

// SOCIAL-09: Caption field for a post draft. Edits a caption owned by the parent and reports it on Continue.
struct PostCaptionField: View {
    // The parent's caption (typing writes to it) and the callback for Continue.
    @Binding var caption: String
    let onContinue: (String) -> Void

    // Text field bound to the caption, plus a Continue button that reports the
    // current caption once per tap, including an empty one (never disabled).
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TextField("Write a caption", text: $caption, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)

            Button {
                onContinue(caption)
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// Preview-only parent. It owns the caption and
// shows the live binding value and what Continue reported, for screenshots.
private struct PostCaptionFieldPreview: View {
    @State private var caption = ""
    @State private var reportedCaption: String?

    var body: some View {
        VStack(spacing: 24) {
            PostCaptionField(caption: $caption) { reported in
                reportedCaption = reported
            }

            Text("Binding: \"\(caption)\"")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let reportedCaption {
                Text("Continue reported: \"\(reportedCaption)\"")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PostCaptionFieldPreview()
}
