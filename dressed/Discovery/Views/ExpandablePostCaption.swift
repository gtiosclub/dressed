//
//  ExpandablePostCaption.swift
//  dressed
//
//  Created by Daniel  Roldan on 10/20/26.
//

import SwiftUI
 
struct ExpandablePostCaption: View {
    /// The post's caption text, supplied by the parent.
    let caption: String
    /// Whether the caption needs an expand control, supplied by the parent.
    let canExpand: Bool
 
    /// Number of lines shown while collapsed.
    var collapsedLineLimit: Int = 3
 
    @State private var isExpanded = false
 
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(caption)
                .font(.subheadline)
                .lineLimit(lineLimit)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
 
            if canExpand {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionTitle)
                .accessibilityHint(isExpanded
                                   ? "Collapses the caption to three lines"
                                   : "Shows the full caption")
            }
        }
    }
 
    /// Collapsed captions are capped; with no expand control there's no way
    /// to reveal hidden text, so the full caption is shown.
    private var lineLimit: Int? {
        guard canExpand else { return nil }
        return isExpanded ? nil : collapsedLineLimit
    }
 
    private var actionTitle: String {
        isExpanded ? "Less" : "More"
    }
}
 
// MARK: - Previews
 
#Preview("Short caption, no expand") {
    ExpandablePostCaption(
        caption: "Test Test TEST",
        canExpand: false
    )
    .padding()
}
 
#Preview("Long caption, expandable") {
    ExpandablePostCaption(
        caption: """
        Line one: thrifted denim jacket
        Line two: vintage band tee
        Line three: black straight-leg jeans
        Line four: white leather sneakers
        Line five: silver chain
        Line six: tote from the farmers market
        """,
        canExpand: true
    )
    .padding()
}
