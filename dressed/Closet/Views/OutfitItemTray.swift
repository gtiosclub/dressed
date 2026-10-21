import SwiftUI
//
//  OutfitItemTray.swift
//  dressed
//
//  Created by Aman Jha on 10/7/26.
//
struct OutfitItem: Identifiable {
    let id: UUID
    let thumbnail: AnyView
    let name: String
    let category: ClothingCategory
    var subtitle: String? = nil  // shown instead of the category label when set

    init(id: UUID, image: Image, name: String, category: ClothingCategory, subtitle: String? = nil) {
        self.id = id
        self.thumbnail = AnyView(image.resizable().scaledToFit())
        self.name = name
        self.category = category
        self.subtitle = subtitle
    }

    init(id: UUID, thumbnail: AnyView, name: String, category: ClothingCategory, subtitle: String? = nil) {
        self.id = id
        self.thumbnail = thumbnail
        self.name = name
        self.category = category
        self.subtitle = subtitle
    }
}

struct OutfitItemTray: View {
    let items: [OutfitItem]
    let onSelect: (UUID) -> Void

    private let laps = 100  // was 10_000; huge ranges made the tray very slow
    private let loopThreshold = 6  // minimum items to have an infinite scroll
    private var isLooping: Bool { items.count >= loopThreshold }
    // Fewer than loopThreshold items scroll once, with no repeats. More than that repeat `laps` times.
    private var lapCount: Int { isLooping ? laps : 1 }
    private let cardWidth: CGFloat = 180  // this needs to match what's in clothingitemcard
    @State private var position: Int?

    // Explicit init: the automatic one is private to this file because of the private properties above.
    init(items: [OutfitItem], onSelect: @escaping (UUID) -> Void) {
        self.items = items
        self.onSelect = onSelect
    }

    var body: some View {
        if items.isEmpty {
            Text("No items available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 100)
        } else if items.count == 1 {
            let item = items[0]
            ClothingItemCard(
                thumbnail: item.thumbnail,
                name: item.name,
                category: item.category,
                subtitle: item.subtitle,
                onTap: { onSelect(item.id) }
            )
            .frame(height: 240)
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(0..<(items.count * lapCount), id: \.self) { index in
                            let item = items[index % items.count]
                            ClothingItemCard(
                                thumbnail: item.thumbnail,
                                name: item.name,
                                category: item.category,
                                subtitle: item.subtitle,
                                onTap: { onSelect(item.id) }
                            )
                            .scrollTransition(.interactive.threshold(.centered), axis: .horizontal) { content, phase in
                                let distance = abs(phase.value)
                                return content
                                    .scaleEffect(1 - 0.3 * distance)
                                    .brightness(-0.45 * distance)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $position)
                .scrollTargetBehavior(.viewAligned)
                // Half the leftover width on each side puts the snapped card in the middle
                .contentMargins(.horizontal, max((geo.size.width - cardWidth) / 2, 0), for: .scrollContent)
            }
            .frame(height: 240)
            .onAppear { recenter() }
            .onChange(of: items.count) { recenter() }
        }
    }

    // Looping trays start in the middle lap so there is room to scroll both ways.
    // Short trays start on the first card.
    private func recenter() {
        position = isLooping ? items.count * (laps / 2) : 0
    }
}

@Observable
final class OutfitTrayViewModel {
    var items: [OutfitItem] = []
    var selectedID: UUID?

    func loadSamples() {
        items = [
            OutfitItem(id: UUID(), image: Image(systemName: "tshirt"), name: "Blue shirt", category: .tops),
            OutfitItem(id: UUID(), image: Image(systemName: "photo"), name: "Black pants", category: .tops),
            OutfitItem(id: UUID(), image: Image(systemName: "shoe"), name: "White sneakers", category: .shoes),
        ]
    }

    func loadMany(count: Int = 50) {
        let symbols = ["tshirt", "photo", "shoe", "hanger", "bag"]
        items = (1...count).map { i in
            OutfitItem(
                id: UUID(),
                image: Image(systemName: symbols[i % symbols.count]),
                name: "Item \(i)",
                category: .tops
            )
        }
    }

    func select(_ id: UUID) {
        selectedID = id
    }
}

#Preview {
    OutfitTrayPreview()
}

private struct OutfitTrayPreview: View {
    @State private var viewModel = OutfitTrayViewModel()

    var body: some View {
        VStack(spacing: 16) {
            OutfitItemTray(items: viewModel.items, onSelect: viewModel.select)
            Text("Items: \(viewModel.items.count)")
            Text("Selected: \(viewModel.selectedID?.uuidString ?? "none")")
                .font(.caption)

            HStack {
                Button("Load 5") { viewModel.loadMany(count: 5) }
                Button("Load 6") { viewModel.loadMany(count: 6) }
                Button("Load 50") { viewModel.loadMany() }
                Button("Clear") { viewModel.items = [] }
            }
        }
    }
}
