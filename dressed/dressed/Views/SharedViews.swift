//
//  SharedViews.swift
//  dressed
//

import SwiftUI

/// Stand-in for a real garment photo until image storage exists.
struct ItemSwatch: View {
    let item: ClothingItem
    var size: CGFloat = 96

    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(item.color.opacity(0.25))
            .overlay {
                Image(systemName: item.category.symbol)
                    .font(.system(size: size * 0.32))
                    .foregroundStyle(item.color == .white ? .gray : item.color)
            }
            .frame(width: size, height: size)
    }
}

struct ItemTile: View {
    let item: ClothingItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ItemSwatch(item: item)
            Text(item.name)
                .font(.caption)
                .lineLimit(2)
                .frame(width: 96, alignment: .leading)
        }
    }
}

struct OutfitCard: View {
    let outfit: Outfit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach(outfit.items) { item in
                    ItemSwatch(item: item, size: 64)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(outfit.name)
                    .font(.headline)
                Text(outfit.occasion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct OutfitDetailView: View {
    let outfit: Outfit

    var body: some View {
        List {
            Section("Pieces") {
                ForEach(outfit.items) { item in
                    HStack(spacing: 12) {
                        ItemSwatch(item: item, size: 48)
                        VStack(alignment: .leading) {
                            Text(item.name)
                            Text(item.category.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(outfit.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        OutfitDetailView(outfit: Outfit.samples[0])
    }
}
