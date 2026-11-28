import SwiftUI

/// Full-screen try-on: faces forward, shown head to toe, with nothing cropped.
/// Tap the shirt, pants or shoes on the avatar (or the chip beside it) and a scrollable picker pops up
/// for that piece.
///
/// Why it stays uncropped (AvatarView's framing, see AvatarScene):
/// - Height: at zoom 1 the figure fills 95% of the view height, feet to head. Zooming keeps the top
///   edge fixed and crops the feet, so this view always passes zoom 1 and has no zoom slider.
/// - Width: the camera is sized by height, so a narrow view crops the arms or skirt hems. The avatar
///   area is therefore never allowed to be narrower than `minAspect` (width / height).
/// - Facing: `allowsInteraction: false` turns off the drag-to-spin and double-tap gestures, so the
///   turntable stays at yaw 0 (facing front).
/// - Overlap: the picker appears at the opposite end of the screen from the piece being changed
///   (shirt -> bottom, pants and shoes -> top), so it never covers what you are editing.
struct FullScreenTryOnView: View {
    @ObservedObject var model: OutfitStudioModel
    @Bindable var tryOn: TryOnEditorModel
    let items: [ClothingItem]
    let image: (ClothingItem) -> Image
    var uiImage: ((ClothingItem) -> UIImage?)?
    /// Kept so existing call sites can still request the flat figure. This screen draws the fitted avatar.
    var use3D: Bool = true

    @Environment(\.dismiss) private var dismiss
    @State private var selectedZone: Zone?

    /// Widest the figure gets is about 0.38 units (hands out to the sides, wide skirt hems); the view
    /// is 1/0.95 units tall. 0.40 leaves a little margin on top of that.
    private static let minAspect: CGFloat = 0.40

    // MARK: - Tap zones

    /// A region of the avatar you can tap, and the closet category it changes.
    private enum Zone: CaseIterable, Identifiable {
        case shirt, pants, shoes

        var id: Self { self }

        /// Closet categories this part of the body can wear.
        var categories: [ClothingCategory] {
            switch self {
            case .shirt: return [.tops, .outerwear]
            case .pants: return [.pants, .skirts, .dresses]
            case .shoes: return [.shoes]
            }
        }

        var category: ClothingCategory { categories[0] }

        func accepts(_ item: ClothingItem) -> Bool {
            categories.contains(item.category) || item.category == .other
        }

        var singular: String {
            switch self {
            case .shirt: return "Top"
            case .pants: return "Bottom"
            case .shoes: return "Shoes"
            }
        }

        var plural: String {
            switch self {
            case .shirt: return "Tops"
            case .pants: return "Bottoms"
            case .shoes: return "Shoes"
            }
        }

        /// Vertical extent of the generated figure, as a fraction of the canvas height from the top.
        var span: ClosedRange<CGFloat> {
            switch self {
            case .shirt: return 0.14...0.52
            case .pants: return 0.48...0.90
            case .shoes: return 0.86...1
            }
        }

        /// Width of the tap area as a fraction of the view width.
        var width: CGFloat {
            switch self {
            case .shirt: return 0.78
            case .pants: return 0.62
            case .shoes: return 0.46
            }
        }

        /// Pants and shoes are low on the screen, so their picker goes at the top (and vice versa).
        var panelAtTop: Bool { self != .shirt }
    }

    // MARK: - Body

    var body: some View {
        avatarArea
            .background(
                LinearGradient(colors: [Color(white: 0.97), Color(white: 0.88)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .overlay {
                if let zone = selectedZone {
                    panel(for: zone)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: zone.panelAtTop ? .top : .bottom)
                        .padding(.top, zone.panelAtTop ? 60 : 0)   // clear of the close button
                        .padding(.bottom, zone.panelAtTop ? 0 : 8)
                        .transition(.move(edge: zone.panelAtTop ? .top : .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .topLeading) { closeButton }
            .animation(.snappy, value: selectedZone)
            .onAppear(perform: refreshTryOnForFullScreen)
            .onChange(of: wornSignature) { _, _ in
                refreshTryOnForFullScreen()
            }
    }

    private var wornSignature: String {
        model.worn
            .map { "\($0.key.rawValue):\($0.value.id)" }
            .sorted()
            .joined(separator: "|")
    }

    /// Matches studio try-on: sync worn slots, rebake the v13 composite, and backfill body-part fits.
    private func refreshTryOnForFullScreen() {
        let photos = Dictionary(
            uniqueKeysWithValues: items.compactMap { item -> (String, UIImage)? in
                guard let photo = photo(for: item) else { return nil }
                return (item.id, photo)
            }
        )
        GarmentBodyPartCoordinator.shared(for: tryOn.closetOwnerId).backfill(items: items, photos: photos)
        tryOn.syncWornItems(
            worn: model.worn,
            uiImage: { photo(for: $0) ?? uiImage?($0) },
            avatarSource: TryOnBitmap.neutralFigure()
        )
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.headline)
                .padding(12)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.leading, 16)
        .padding(.top, 8)
        .accessibilityLabel("Close")
    }

    // MARK: - Avatar and tap zones

    private var avatarArea: some View {
        GeometryReader { geo in
            // Never let the avatar get narrower than the figure needs; shrink its height instead.
            let height = min(geo.size.height, geo.size.width / Self.minAspect)
            let size = CGSize(width: geo.size.width, height: height)

            ZStack {
                TryOnFittedFigure(model: tryOn)
                    .allowsHitTesting(false)

                ForEach(Zone.allCases) { zone in
                    zoneButton(zone, in: size)
                    zoneChip(zone, in: size)
                }
            }
            .frame(width: size.width, height: size.height)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func toggle(_ zone: Zone) {
        selectedZone = selectedZone == zone ? nil : zone
    }

    /// The invisible tap area over one part of the body. It lights up while its picker is open.
    private func zoneButton(_ zone: Zone, in size: CGSize) -> some View {
        let top = zone.span.lowerBound * size.height
        let bottom = zone.span.upperBound * size.height
        let isSelected = selectedZone == zone

        return Button {
            toggle(zone)
        } label: {
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            isSelected ? Color.accentColor : Color.clear,
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                        )
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: zone.width * size.width, height: max(bottom - top, 44))
        .position(x: size.width / 2, y: (top + bottom) / 2)
        .accessibilityLabel("Change \(zone.singular)")
    }

    /// A small label at the right edge, level with its zone, so people can see the zones exist.
    private func zoneChip(_ zone: Zone, in size: CGSize) -> some View {
        let centerY = (zone.span.lowerBound + zone.span.upperBound) / 2 * size.height
        let isSelected = selectedZone == zone

        return Button {
            toggle(zone)
        } label: {
            Text(zone.singular)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(isSelected ? Color.accentColor : Color.clear, in: Capsule())
                .background(.thinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .position(x: size.width - 44, y: centerY)
        .accessibilityHidden(true)   // the zone button already carries the label
    }

    // MARK: - Picker

    private func panel(for zone: Zone) -> some View {
        let options = items.filter { zone.accepts($0) }
        let wornItem = wornItem(in: zone)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(zone.plural)
                    .font(.headline)
                Spacer()
                if wornItem != nil {
                    Button("Take off") { clear(zone) }
                        .font(.subheadline)
                }
                Button("Done") { selectedZone = nil }
                    .font(.subheadline.weight(.semibold))
            }

            if options.isEmpty {
                Text("No \(zone.plural.lowercased()) in your closet yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 96)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(options) { item in
                            optionButton(item)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)   // room for the selection outline
                }
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 12)
    }

    private func wornItem(in zone: Zone) -> ClothingItem? {
        zone.categories.compactMap { model.worn[$0] }.first
    }

    private func photo(for item: ClothingItem) -> UIImage? {
        if let image = uiImage?(item) { return image }
        if item.imagePath.hasPrefix("/") { return UIImage(contentsOfFile: item.imagePath) }
        return nil
    }

    private func clear(_ zone: Zone) {
        for category in zone.categories {
            if let worn = model.worn[category] {
                tryOn.takeOff(itemID: worn.id, category: category)
            }
            model.worn[category] = nil
        }
    }

    private func wear(_ item: ClothingItem, in zone: Zone) {
        let category = zone.categories.contains(item.category) ? item.category : zone.category
        if model.worn[category]?.id == item.id {
            clear(zone)
            return
        }
        // Clear only this body zone in the studio model; other slots (pants, shoes, etc.) stay worn.
        clear(zone)
        var placed = item
        placed.category = category
        model.worn[category] = placed
        guard let template = TryOnTemplateID.suggested(for: category) else {
            tryOn.message = "\(zone.singular) does not have a fitting template yet."
            return
        }
        guard let photo = photo(for: item) else {
            tryOn.message = "This piece has no photo to fit."
            return
        }
        tryOn.wearFromCloset(
            item: placed,
            template: template,
            image: photo,
            avatarSource: TryOnBitmap.neutralFigure()
        )
    }

    private func optionButton(_ item: ClothingItem) -> some View {
        let isWorn = Zone.allCases.contains { wornItem(in: $0)?.id == item.id }

        return Button {
            guard let zone = selectedZone else { return }
            wear(item, in: zone)
        } label: {
            VStack(spacing: 4) {
                image(item)
                    .resizable()
                    .scaledToFit()
                    .padding(6)
                    .frame(width: 76, height: 76)
                    .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isWorn ? Color.accentColor : .clear, lineWidth: 3)
                    }
                Text(item.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .frame(width: 76)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(isWorn ? .isSelected : [])
    }
}

#Preview {
    FullScreenTryOnView(
        model: OutfitStudioModel(),
        tryOn: TryOnEditorModel(ownerId: "preview"),
        items: ClothingItem.previewSamples,
        image: { _ in Image(systemName: "photo") }
    )
}
