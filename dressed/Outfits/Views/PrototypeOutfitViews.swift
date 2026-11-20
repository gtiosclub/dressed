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

/// Create Outfit (Figma 1273:173): pick pieces from the closet, name the outfit, then Create Outfit.
/// Pieces are placed automatically; one piece per clothing category.
struct PrototypeOutfitEditorView: View {
    @ObservedObject var closet: PrototypeClosetStore
    @ObservedObject var outfits: PrototypeOutfitStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var placements: [OutfitPlacement] = []
    @State private var filter: ClothingCategory?
    @State private var saveError: String?
    @State private var createdCount = 0

    private let columns = [GridItem(.flexible(), spacing: DSSpacing.md), GridItem(.flexible(), spacing: DSSpacing.md)]

    private var visibleItems: [ClothingItem] {
        closet.items.filter { filter == nil || $0.category == filter }
    }

    private var selectedItems: [ClothingItem] {
        placements.compactMap { closet.item(id: $0.itemId) }
    }

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !placements.isEmpty
    }

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            DSBackHeader(title: "Select Items", onBack: { dismiss() }) {
                HStack(spacing: DSSpacing.xs) {
                    ForEach(selectedItems.prefix(3)) { item in
                        DSThumbnailSlot { pieceImage(item) }
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: placements.count)
            }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.top, DSSpacing.sm)

            DSLabeledField(label: "Outfit Name", prompt: "Name your outfit", text: $name)
                .padding(.horizontal, DSSpacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.sm) {
                    DSChip(title: "All", isSelected: filter == nil, style: .flat) { filter = nil }
                    ForEach(ClothingCategory.allCases, id: \.self) { category in
                        DSChip(title: category.rawValue.capitalized, isSelected: filter == category, style: .flat) {
                            filter = category
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
            }

            if closet.items.isEmpty {
                DSEmptyState(icon: "TablerHanger2", title: "Add a piece first",
                             message: "Outfits are made from pieces in your closet.")
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                        ForEach(visibleItems) { item in
                            let isChecked = placements.contains { $0.itemId == item.id }
                            Button { toggle(item) } label: {
                                DSTile(isChecked: isChecked) { pieceImage(item) }
                            }
                            .buttonStyle(.dsPress(0.98))
                            .accessibilityLabel("\(item.name), \(isChecked ? "selected" : "not selected")")
                        }
                    }
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.bottom, 50 + 2 * DSSpacing.lg)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .overlay(alignment: .bottom) {
            Button { save() } label: {
                Text("Create Outfit").frame(maxWidth: .infinity)
            }
                .buttonStyle(.ds(.primary))
                .opacity(canCreate ? 1 : 0.4)
                .animation(.easeOut(duration: 0.2), value: canCreate)
                .disabled(!canCreate)
                // Opaque backing so pieces don't show through the dimmed disabled button.
                .background(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous).fill(DSColor.background))
                .dsShadow(.floating)
                .padding(.horizontal, DSSpacing.lg)
                .padding(.bottom, DSSpacing.sm)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.success, trigger: createdCount)
        .alert("Could not create outfit", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    @ViewBuilder
    private func pieceImage(_ item: ClothingItem) -> some View {
        if let image = closet.image(for: item) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            DSIcon("TablerPhoto", size: 24).foregroundStyle(DSColor.textMuted)
        }
    }

    private func toggle(_ item: ClothingItem) {
        if placements.contains(where: { $0.itemId == item.id }) {
            placements.removeAll { $0.itemId == item.id }
        } else {
            // One piece per category: choosing another replaces the earlier one.
            placements.removeAll { placement in
                closet.item(id: placement.itemId)?.category == item.category
            }
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
            createdCount += 1
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// Outfit detail (Figma 1280:421): collage of the pieces, then one row per piece.
struct PrototypeOutfitDetailView: View {
    let outfit: Outfit
    let onTryOutfit: (Outfit) -> Void
    let onTryOn: (ClothingItem) -> Void
    @ObservedObject var closet: PrototypeClosetStore
    @Environment(\.dismiss) private var dismiss

    init(outfit: Outfit, closet: PrototypeClosetStore,
         onTryOutfit: @escaping (Outfit) -> Void, onTryOn: @escaping (ClothingItem) -> Void = { _ in }) {
        self.outfit = outfit
        self.closet = closet
        self.onTryOutfit = onTryOutfit
        self.onTryOn = onTryOn
    }

    private var pieces: [ClothingItem] { outfit.placements.compactMap { closet.item(id: $0.itemId) } }
    private var missingCount: Int { outfit.placements.count - pieces.count }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            DSBackHeader(title: outfit.name ?? "Outfit", onBack: { dismiss() })
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.sm)

            ScrollView {
                VStack(spacing: DSSpacing.md) {
                    DSOutfitCollage(count: min(4, pieces.count), cornerRadius: DSRadius.md, showsEmptyCells: false) { index in
                        pieceImage(pieces[index])
                    }

                    VStack(spacing: DSSpacing.xs) {
                        ForEach(pieces) { item in
                            DSItemRow(title: item.name, trailing: {
                                DSMoreMenu(accessibilityLabel: "More options for \(item.name)") {
                                    Button { onTryOn(item); dismiss() } label: {
                                        Label("Try On", tabler: "TablerUserCircle")
                                    }
                                }
                            }) { pieceImage(item) }
                        }
                        if missingCount > 0 {
                            Label(missingCount == 1 ? "A piece is no longer in your closet" : "\(missingCount) pieces are no longer in your closet",
                                  tabler: "TablerAlertTriangle")
                                .font(DSFont.body)
                                .foregroundStyle(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Button {
                        onTryOutfit(outfit)
                        dismiss()
                    } label: {
                        Label("Try On Outfit", tabler: "TablerUserCircle").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.ds(.secondary))
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.bottom, DSSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DSColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func pieceImage(_ item: ClothingItem) -> some View {
        if let image = closet.image(for: item) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            DSIcon("TablerPhoto", size: 24).foregroundStyle(DSColor.textMuted)
        }
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
                                Image("TablerPhoto")
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
                        DSIcon("TablerAlertTriangle", size: 20)
                            .foregroundStyle(.orange)
                            .accessibilityHidden(false)
                            .accessibilityLabel("Missing piece")
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
