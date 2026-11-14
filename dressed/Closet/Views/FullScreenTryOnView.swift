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
    @Bindable var model: OutfitStudioModel
    let items: [ClothingItem]
    let image: (ClothingItem) -> Image
    var uiImage: ((ClothingItem) -> UIImage?)?
    /// Pass false to use the flat 2D avatar once that path is the default.
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

        var category: ClothingCategory {
            switch self {
            case .shirt: return .tops
            case .pants: return .pants
            case .shoes: return .shoes
            }
        }

        var singular: String {
            switch self {
            case .shirt: return "Shirt"
            case .pants: return "Pants"
            case .shoes: return "Shoes"
            }
        }

        var plural: String {
            switch self {
            case .shirt: return "Shirts"
            case .pants: return "Pants"
            case .shoes: return "Shoes"
            }
        }

        /// Vertical extent as fractions of the avatar view's height, measured from the top.
        /// These follow AvatarScene's framing (figure 1 unit tall, view 1/0.95 units tall, feet near
        /// 0.975): shoulders at ~0.20, hem of a tee at ~0.48, ankles at ~0.88, floor at ~0.975.
        /// Tune these three ranges if the zones feel off.
        var span: ClosedRange<CGFloat> {
            switch self {
            case .shirt: return 0.18...0.47
            case .pants: return 0.47...0.91
            case .shoes: return 0.91...1
            }
        }

        /// Full width of the tap area, in model units (the figure is 1 unit tall).
        var width: CGFloat {
            switch self {
            case .shirt: return 0.30   // includes the sleeves
            case .pants: return 0.24
            case .shoes: return 0.15
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
                AvatarView(
                    look: model.look,
                    worn: model.worn,
                    image: image,
                    uiImage: uiImage,
                    zoom: 1,
                    use3D: use3D,
                    allowsInteraction: false
                )

                // Tapping empty space closes the picker.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { selectedZone = nil }

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
        let unit = size.height * 0.95   // points per model unit at zoom 1
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
        .frame(width: zone.width * unit, height: bottom - top)
        .position(x: size.width / 2, y: (top + bottom) / 2)
        .accessibilityLabel("Change \(zone.singular.lowercased())")
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
        let options = items.filter { $0.category == zone.category }
        let wornItem = model.worn[zone.category]

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(zone.plural)
                    .font(.headline)
                Spacer()
                if wornItem != nil {
                    Button("Take off") { model.worn[zone.category] = nil }
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

    private func optionButton(_ item: ClothingItem) -> some View {
        let isWorn = model.worn[item.category]?.id == item.id

        return Button {
            model.toggle(item)   // tapping the worn item takes it off; another item replaces it
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
        items: ClothingItem.previewSamples,
        image: { _ in Image(systemName: "photo") }
    )
}
