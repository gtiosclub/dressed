//
//  DiscoverySectionSwift.swift
//  dressed
//
//  Created by Sparsh Jain on 10/20/26.
//

import SwiftUI

enum DiscoverySection: String, CaseIterable, Identifiable {
    case feed
    case search

    var id: Self { self }

    var title: String {
        switch self {
        case .feed: "Feed"
        case .search: "Search"
        }
    }
}

struct DiscoverySectionSwitch: View {
    let selection: DiscoverySection
    let onSelect: (DiscoverySection) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(DiscoverySection.allCases) { section in
                option(for: section)
            }
        }
        .padding(4)
        .background(Color(.secondarySystemBackground), in: Capsule())
    }

    private func option(for section: DiscoverySection) -> some View {
        let isSelected = section == selection

        return Button {
            onSelect(section)
        } label: {
            Text(section.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color(.systemBackground) : Color.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? Color.primary : Color.clear, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("discoverySwitch.\(section.rawValue)")
    }
}

private struct DiscoverySectionSwitchPreview: View {
    @State private var selection: DiscoverySection
    @State private var lastReported: DiscoverySection?

    init(selection: DiscoverySection = .feed) {
        _selection = State(initialValue: selection)
    }

    var body: some View {
        VStack(spacing: 16) {
            DiscoverySectionSwitch(selection: selection) { requested in
                lastReported = requested
                selection = requested
            }

            Text("Selected: \(selection.title)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let lastReported {
                Text("Switch reported: \(lastReported.rawValue)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview("Feed selected") {
    DiscoverySectionSwitch(selection: .feed, onSelect: { _ in })
        .padding()
}

#Preview("Search selected") {
    DiscoverySectionSwitch(selection: .search, onSelect: { _ in })
        .padding()
}

#Preview("Interactive") {
    DiscoverySectionSwitchPreview()
}
