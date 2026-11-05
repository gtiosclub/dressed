import SwiftUI

enum OutfitCanvasFixture {
    static let ownerId = "canvas-fixture-owner"
    static let items = [
        ClothingItem(id: "fixture-shirt", ownerId: ownerId, name: "Blue shirt", category: .tops,
                     imagePath: "fixture-shirt.png", createdAt: .distantPast),
        ClothingItem(id: "fixture-pants", ownerId: ownerId, name: "Dark pants", category: .pants,
                     imagePath: "fixture-pants.png", createdAt: .distantPast)
    ]
    static let placements = [
        OutfitPlacement(itemId: "fixture-shirt", centerX: 0.48, centerY: 0.30,
                        width: 0.42, rotationDegrees: 0, layer: 1),
        OutfitPlacement(itemId: "fixture-pants", centerX: 0.53, centerY: 0.67,
                        width: 0.50, rotationDegrees: 0, layer: 0)
    ]
}

struct PrototypeOutfitEditorView: View {
    @ObservedObject var closet: PrototypeClosetStore
    @ObservedObject var outfits: PrototypeOutfitStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var placements: [OutfitPlacement] = []
    @State private var selectedItemId: String?
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Outfit Name") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("Choose Pieces") {
                    if closet.items.isEmpty {
                        Text("Add a piece to your closet first.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(closet.items) { item in
                        Button {
                            toggle(item)
                        } label: {
                            HStack {
                                if let image = closet.image(for: item) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 44, height: 44)
                                        .clipped()
                                }
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                    Text(item.category.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if placements.contains(where: { $0.itemId == item.id }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.name), \(placements.contains(where: { $0.itemId == item.id }) ? "selected" : "not selected")")
                    }
                }

                if !placements.isEmpty {
                    Section("Arrange Pieces") {
                        Text("Drag pieces to arrange them.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        OutfitCanvasView(
                            placements: $placements,
                            selectedItemId: $selectedItemId,
                            closet: closet,
                            editable: true
                        )
                            .frame(height: 340)
                            .listRowInsets(EdgeInsets())
                        if let selectedItemId,
                           let index = placements.firstIndex(where: { $0.itemId == selectedItemId }),
                           let item = closet.item(id: selectedItemId) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Editing \(item.name)")
                                    .font(.subheadline.bold())
                                HStack {
                                    Text("Size")
                                    Slider(value: $placements[index].width, in: 0.2...0.8)
                                        .accessibilityLabel("Size of \(item.name)")
                                    Text("\(Int(placements[index].width * 100))%")
                                        .monospacedDigit()
                                        .frame(width: 44, alignment: .trailing)
                                }
                                HStack {
                                    Button("Send backward", systemImage: "arrow.down") {
                                        moveLayer(itemId: selectedItemId, direction: -1)
                                    }
                                    .disabled(index == 0)
                                    Button("Bring forward", systemImage: "arrow.up") {
                                        moveLayer(itemId: selectedItemId, direction: 1)
                                    }
                                    .disabled(index == placements.count - 1)
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            Text("Tap a piece to resize it or change its layer. Drag a piece to move it.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("New Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || placements.isEmpty)
                }
            }
            .alert("Could not save outfit", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Please try again.")
            }
        }
    }

    private func toggle(_ item: ClothingItem) {
        if placements.contains(where: { $0.itemId == item.id }) {
            placements.removeAll { $0.itemId == item.id }
        } else {
            let count = placements.count
            placements.append(OutfitPlacement(
                itemId: item.id,
                centerX: 0.3 + Double(count % 3) * 0.2,
                centerY: 0.3 + Double(count / 3) * 0.2,
                width: 0.38,
                rotationDegrees: 0,
                layer: count
            ))
        }
    }

    private func save() {
        do {
            try outfits.save(name: name, placements: placements, availableItems: closet.items)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func moveLayer(itemId: String, direction: Int) {
        guard let index = placements.firstIndex(where: { $0.itemId == itemId }) else { return }
        let destination = index + direction
        guard placements.indices.contains(destination) else { return }
        placements.swapAt(index, destination)
        for layer in placements.indices {
            placements[layer].layer = layer
        }
    }
}

struct PrototypeOutfitDetailView: View {
    let outfit: Outfit
    @ObservedObject var closet: PrototypeClosetStore
    @State private var placements: [OutfitPlacement]

    init(outfit: Outfit, closet: PrototypeClosetStore) {
        self.outfit = outfit
        self.closet = closet
        _placements = State(initialValue: outfit.placements)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                OutfitCanvasView(placements: $placements, selectedItemId: .constant(nil), closet: closet, editable: false)
                    .frame(height: 400)
                Text("Pieces")
                    .font(.title2.bold())
                ForEach(outfit.placements, id: \.itemId) { placement in
                    if let item = closet.item(id: placement.itemId) {
                        Label(item.name, systemImage: "checkmark.circle")
                    } else {
                        Label("Piece no longer in closet", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(outfit.name ?? "Outfit")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct OutfitCanvasView: View {
    @Binding var placements: [OutfitPlacement]
    @Binding var selectedItemId: String?
    @ObservedObject var closet: PrototypeClosetStore
    let editable: Bool
    var fixtureItems: [ClothingItem] = []

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                ForEach(orderedIndices, id: \.self) { index in
                    let placement = placements[index]
                    if let item = closet.item(id: placement.itemId)
                        ?? fixtureItems.first(where: { $0.id == placement.itemId }) {
                        Group {
                            if let image = closet.image(for: item) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                                    .padding()
                            }
                        }
                        .frame(width: geometry.size.width * placement.width, height: 140)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            if editable && selectedItemId == item.id {
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentColor, lineWidth: 3)
                            }
                        }
                        .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
                        .rotationEffect(.degrees(placement.rotationDegrees))
                        .position(x: geometry.size.width * placement.centerX,
                                  y: geometry.size.height * placement.centerY)
                        .accessibilityLabel(item.name)
                        .onTapGesture { if editable { selectedItemId = item.id } }
                        .gesture(DragGesture(minimumDistance: 4, coordinateSpace: .named("outfitCanvas"))
                            .onChanged { value in
                                guard editable, geometry.size.width > 0, geometry.size.height > 0 else { return }
                                selectedItemId = item.id
                                let halfWidth = placements[index].width / 2
                                placements[index].centerX = min(max(Double(value.location.x / geometry.size.width), halfWidth), 1 - halfWidth)
                                let halfHeight = min(0.48, Double(140 / max(geometry.size.height, 1)) / 2)
                                placements[index].centerY = min(max(Double(value.location.y / geometry.size.height), halfHeight), 1 - halfHeight)
                            })
                        .allowsHitTesting(editable)
                    } else {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .position(x: geometry.size.width * placement.centerX,
                                      y: geometry.size.height * placement.centerY)
                    }
                }
            }
            .coordinateSpace(name: "outfitCanvas")
        }
    }

    private var orderedIndices: [Int] {
        placements.indices.sorted { placements[$0].layer < placements[$1].layer }
    }
}

#Preview("Two-piece outfit canvas") {
    @Previewable @State var placements = OutfitCanvasFixture.placements
    @Previewable @State var selectedItemId: String? = "fixture-shirt"

    OutfitCanvasView(
        placements: $placements,
        selectedItemId: $selectedItemId,
        closet: PrototypeClosetStore(ownerId: OutfitCanvasFixture.ownerId),
        editable: true,
        fixtureItems: OutfitCanvasFixture.items
    )
    .frame(height: 360)
    .padding()
}
