import SwiftUI

struct PrototypeOutfitEditorView: View {
    @ObservedObject var closet: PrototypeClosetStore
    @ObservedObject var outfits: PrototypeOutfitStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var placements: [OutfitPlacement] = []
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
                        OutfitCanvasView(placements: $placements, closet: closet, editable: true)
                            .frame(height: 340)
                            .listRowInsets(EdgeInsets())
                        ForEach(placements, id: \.itemId) { placement in
                            if let item = closet.item(id: placement.itemId) {
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                        .font(.subheadline.bold())
                                    HStack {
                                        moveButton("Left", icon: "arrow.left", itemId: item.id, dx: -0.1, dy: 0)
                                        moveButton("Up", icon: "arrow.up", itemId: item.id, dx: 0, dy: -0.1)
                                        moveButton("Down", icon: "arrow.down", itemId: item.id, dx: 0, dy: 0.1)
                                        moveButton("Right", icon: "arrow.right", itemId: item.id, dx: 0.1, dy: 0)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
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

    private func moveButton(_ direction: String, icon: String, itemId: String, dx: Double, dy: Double) -> some View {
        Button {
            guard let index = placements.firstIndex(where: { $0.itemId == itemId }) else { return }
            placements[index].centerX = min(max(placements[index].centerX + dx, 0.15), 0.85)
            placements[index].centerY = min(max(placements[index].centerY + dy, 0.15), 0.85)
        } label: {
            Image(systemName: icon)
                .frame(maxWidth: .infinity)
        }
        .accessibilityLabel("Move \(closet.item(id: itemId)?.name ?? "piece") \(direction.lowercased())")
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
                OutfitCanvasView(placements: $placements, closet: closet, editable: false)
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
    @ObservedObject var closet: PrototypeClosetStore
    let editable: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                ForEach(placements.indices, id: \.self) { index in
                    let placement = placements[index]
                    if let item = closet.item(id: placement.itemId) {
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
                        .shadow(radius: 4)
                        .rotationEffect(.degrees(placement.rotationDegrees))
                        .position(x: geometry.size.width * placement.centerX,
                                  y: geometry.size.height * placement.centerY)
                        .accessibilityLabel(item.name)
                        .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .named("outfitCanvas"))
                            .onChanged { value in
                                guard editable, geometry.size.width > 0, geometry.size.height > 0 else { return }
                                placements[index].centerX = min(max(Double(value.location.x / geometry.size.width), 0.15), 0.85)
                                placements[index].centerY = min(max(Double(value.location.y / geometry.size.height), 0.15), 0.85)
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
}
