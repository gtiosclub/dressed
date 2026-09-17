//
//  TodayView.swift
//  dressed
//

import SwiftUI

/// Placeholder home screen: greeting, a suggested outfit, and recent items.
struct TodayView: View {
    @EnvironmentObject private var session: SessionStore

    private let suggestion = Outfit.samples[0]
    private let recent = Array(ClothingItem.samples.prefix(4))

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    suggestedOutfit
                    recentlyAdded
                }
                .padding()
            }
            .navigationTitle("Today")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Good morning, \(session.displayName)")
                .font(.title2.bold())
            Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                .foregroundStyle(.secondary)
        }
    }

    private var suggestedOutfit: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's pick")
                .font(.headline)

            NavigationLink {
                OutfitDetailView(outfit: suggestion)
            } label: {
                OutfitCard(outfit: suggestion)
            }
            .buttonStyle(.plain)
        }
    }

    private var recentlyAdded: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently added")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recent) { item in
                        ItemTile(item: item)
                    }
                }
            }
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(SessionStore())
}
