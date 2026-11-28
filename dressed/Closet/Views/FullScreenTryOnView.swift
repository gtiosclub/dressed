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
    /// When true, the screen is the Avatar tab root and the close control is hidden.
    var isTabRoot: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var selectedZone: Zone?
    @State private var shareSnapshot: UIImage?

  @State private var viewportScale: CGFloat = 1
  @State private var viewportScaleBase: CGFloat = 1
  @State private var viewportOffset: CGSize = .zero
  @State private var viewportOffsetBase: CGSize = .zero
  @State private var canvasHeight: CGFloat = 1

    /// Widest the figure gets is about 0.38 units (hands out to the sides, wide skirt hems); the view
    /// is 1/0.95 units tall. 0.40 leaves a little margin on top of that.
    private static let minAspect: CGFloat = 0.40
    private static let maxViewportScale: CGFloat = 3.5

    // MARK: - Tap zones

    /// A region of the avatar you can tap, and the closet category it changes.
    private enum Zone: CaseIterable, Identifiable {
        case hat, shirt, pants, shoes

        var id: Self { self }

        /// Closet categories this part of the body can wear.
        var categories: [ClothingCategory] {
            switch self {
            case .hat: return [.accessories]
            case .shirt: return [.tops, .outerwear]
            case .pants: return [.pants, .skirts, .dresses]
            case .shoes: return [.shoes]
            }
        }

        var category: ClothingCategory { categories[0] }

        func accepts(_ item: ClothingItem) -> Bool {
            switch self {
            case .hat: return item.category == .accessories && !item.isScarfLike
            case .shirt:
                return categories.contains(item.category) || item.isScarfLike || item.category == .other
            case .pants: return [.pants, .skirts, .dresses].contains(item.category)
            case .shoes: return item.category == .shoes
            }
        }

        var singular: String {
            switch self {
            case .hat: return "Hat"
            case .shirt: return "Top"
            case .pants: return "Bottom"
            case .shoes: return "Shoes"
            }
        }

        var plural: String {
            switch self {
            case .hat: return "Hats"
            case .shirt: return "Tops"
            case .pants: return "Bottoms"
            case .shoes: return "Shoes"
            }
        }

        /// Vertical extent of the generated figure, as a fraction of the canvas height from the top.
        var span: ClosedRange<CGFloat> {
            switch self {
            case .hat: return 0.03...0.22
            case .shirt: return 0.14...0.52
            case .pants: return 0.48...0.90
            case .shoes: return 0.86...1
            }
        }

        /// Width of the tap area as a fraction of the view width.
        var width: CGFloat {
            switch self {
            case .hat: return 0.52
            case .shirt: return 0.78
            case .pants: return 0.62
            case .shoes: return 0.46
            }
        }

        /// Pants and shoes are low on the screen, so their picker goes at the top (and vice versa).
        var panelAtTop: Bool { self != .shirt }
    }

    private enum ZoomBodyRegion: String {
        case full = "Full outfit"
        case top = "Top"
        case torso = "Torso"
        case legs = "Legs"
        case feet = "Feet"
    }

    // MARK: - Body

    var body: some View {
        avatarArea
            .background(
                LinearGradient(
                    colors: [DSColor.raised, DSColor.secondaryFill],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .overlay {
                if let zone = selectedZone {
                    panel(for: zone)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: zone.panelAtTop ? .top : .bottom)
                        .padding(.top, zone.panelAtTop ? 72 : 0)
                        .padding(.bottom, zone.panelAtTop ? 0 : DSSpacing.sm)
                        .transition(.move(edge: zone.panelAtTop ? .top : .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .topLeading) {
                if !isTabRoot {
                    closeButton
                }
            }
            .overlay(alignment: .topTrailing) { topTrailingControls }
            .overlay(alignment: .bottomLeading) { undoRedoBar }
            .animation(.snappy, value: selectedZone)
            .animation(.snappy, value: viewportScale)
            .task(id: wornSignature) {
                await refreshTryOnForFullScreen()
                refreshShareSnapshot()
            }
            .onChange(of: model.canUndo) { _, _ in refreshShareSnapshot() }
            .onChange(of: model.canRedo) { _, _ in refreshShareSnapshot() }
    }

    private var wornSignature: String {
        model.worn
            .map { "\($0.key.rawValue):\($0.value.id)" }
            .sorted()
            .joined(separator: "|")
    }

    private var itemIDs: Set<String> { Set(items.map(\.id)) }

    /// Matches studio try-on: sync worn slots, hydrate body-part refs, render one aligned outfit composite, then draw.
    private func refreshTryOnForFullScreen() async {
        let photos = Dictionary(
            uniqueKeysWithValues: items.compactMap { item -> (String, UIImage)? in
                guard let photo = photo(for: item) else { return nil }
                return (item.id, photo)
            }
        )
        let coordinator = GarmentBodyPartCoordinator.shared(for: tryOn.closetOwnerId)
        coordinator.registerCachedBodyParts(items: items, tryOn: tryOn)
        coordinator.backfill(items: items, photos: photos)
        await tryOn.hydrateWornBodyPartsFromCache(worn: model.worn)
        tryOn.syncWornItems(
            worn: model.worn,
            uiImage: { photo(for: $0) ?? uiImage?($0) },
            avatarSource: TryOnBitmap.neutralFigure()
        )
        await tryOn.awaitBodyPartCompositeIdle()
    }

    private var closeButton: some View {
        DSCloseButton { dismiss() }
            .padding(.leading, DSSpacing.lg)
            .padding(.top, DSSpacing.sm)
    }

    @ViewBuilder
    private var topTrailingControls: some View {
        VStack(alignment: .trailing, spacing: DSSpacing.sm) {
            shareButton
            if let region = zoomRegionLabel {
                zoomRegionBadge(region)
            }
        }
        .padding(.trailing, DSSpacing.lg)
        .padding(.top, DSSpacing.sm)
    }

    @ViewBuilder
    private var shareButton: some View {
        if let snapshot = shareSnapshot {
            ShareLink(
                item: Image(uiImage: snapshot),
                preview: SharePreview("My outfit", image: Image(uiImage: snapshot))
            ) {
                DSIcon("TablerUpload", size: 22)
                    .foregroundStyle(DSColor.iconMuted)
                    .frame(width: 43, height: 43)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Share outfit")
            .accessibilityIdentifier("tryon.share")
        } else {
            Button(action: refreshShareSnapshot) {
                DSIcon("TablerUpload", size: 22)
                    .foregroundStyle(DSColor.iconMuted)
                    .frame(width: 43, height: 43)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(true)
            .opacity(0.45)
            .accessibilityLabel("Share outfit")
            .accessibilityIdentifier("tryon.share")
        }
    }

    private func zoomRegionBadge(_ region: ZoomBodyRegion) -> some View {
        HStack(spacing: DSSpacing.xs) {
            DSIcon("TablerArrowsDiagonalMinimize2", size: 14)
            Text(region.rawValue)
                .font(DSFont.badge.weight(.semibold))
        }
        .foregroundStyle(DSColor.textStrong)
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(.thinMaterial, in: Capsule())
        .accessibilityIdentifier("tryon.zoom-region")
        .accessibilityLabel("Zoomed in, showing \(region.rawValue)")
    }

    private var undoRedoBar: some View {
        OutfitUndoRedoButtons(
            canUndo: model.canUndo,
            canRedo: model.canRedo,
            undo: { model.undo(available: itemIDs) },
            redo: { model.redo(available: itemIDs) }
        )
        .padding(DSSpacing.sm)
    }

    private var zoomRegionLabel: ZoomBodyRegion? {
        guard viewportScale > 1.02, canvasHeight > 1 else { return nil }
        let normalizedCenterY = 0.5 - Double(viewportOffset.height / (canvasHeight * viewportScale))
        let y = min(max(normalizedCenterY, 0), 1)
        if y < 0.16 { return .top }
        if y < 0.48 { return .torso }
        if y < 0.84 { return .legs }
        return .feet
    }

    // MARK: - Avatar and tap zones

    private var avatarArea: some View {
        GeometryReader { geo in
            let height = min(geo.size.height, geo.size.width / Self.minAspect)
            let size = CGSize(width: geo.size.width, height: height)

            ZStack {
                TryOnFittedFigure(model: tryOn)
                    .allowsHitTesting(false)

                ForEach(Zone.allCases) { zone in
                    zoneButton(zone, in: size)
                }
            }
            .scaleEffect(viewportScale)
            .offset(viewportOffset)
            .gesture(viewportMagnification)
            .simultaneousGesture(viewportPan)
            .frame(width: size.width, height: size.height)
            .frame(width: geo.size.width, height: geo.size.height)
            .onAppear { canvasHeight = height }
            .onChange(of: height) { _, newHeight in canvasHeight = newHeight }
        }
    }

    private var viewportMagnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let next = viewportScaleBase * value
                viewportScale = min(max(next, 1), Self.maxViewportScale)
            }
            .onEnded { _ in
                viewportScaleBase = viewportScale
                if viewportScale < 1.02 {
                    withAnimation(.snappy) {
                        viewportScale = 1
                        viewportScaleBase = 1
                        viewportOffset = .zero
                        viewportOffsetBase = .zero
                    }
                }
            }
    }

    private var viewportPan: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard viewportScale > 1.02 else { return }
                viewportOffset = CGSize(
                    width: viewportOffsetBase.width + value.translation.width,
                    height: viewportOffsetBase.height + value.translation.height
                )
            }
            .onEnded { _ in
                viewportOffsetBase = viewportOffset
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
            RoundedRectangle(cornerRadius: DSRadius.md)
                .fill(isSelected ? DSColor.brand.opacity(0.14) : Color.clear)
                .overlay {
                    RoundedRectangle(cornerRadius: DSRadius.md)
                        .strokeBorder(
                            isSelected ? DSColor.brand : Color.clear,
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

    // MARK: - Picker

    private func panel(for zone: Zone) -> some View {
        let options = items.filter { zone.accepts($0) }
        let wornItem = wornItem(in: zone)

        return VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text(zone.plural)
                    .font(DSFont.bodyEmphasis)
                Spacer()
                if wornItem != nil {
                    Button("Take off") { clear(zone) }
                        .font(DSFont.body)
                }
                Button("Done") { selectedZone = nil }
                    .font(DSFont.button)
            }

            if options.isEmpty {
                Text("No \(zone.plural.lowercased()) in your closet yet")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 96)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSSpacing.sm) {
                        ForEach(options) { item in
                            optionButton(item)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 3)
                }
            }
        }
        .padding(DSSpacing.md)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DSRadius.md))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, DSSpacing.sm)
    }

    private func wornItem(in zone: Zone) -> ClothingItem? {
        switch zone {
        case .hat:
            if let item = model.worn[.accessories], !item.isScarfLike { return item }
            return nil
        case .shirt:
            if let scarf = model.worn[.accessories], scarf.isScarfLike { return scarf }
            return zone.categories.compactMap { model.worn[$0] }.first
        default:
            return zone.categories.compactMap { model.worn[$0] }.first
        }
    }

    private func photo(for item: ClothingItem) -> UIImage? {
        if let image = uiImage?(item) { return image }
        if item.imagePath.hasPrefix("/") { return UIImage(contentsOfFile: item.imagePath) }
        return nil
    }

    private func clear(_ zone: Zone) {
        switch zone {
        case .hat:
            if let worn = model.worn[.accessories], !worn.isScarfLike {
                tryOn.takeOff(itemID: worn.id, category: .accessories)
                model.worn[.accessories] = nil
            }
        case .shirt:
            for category in zone.categories {
                if let worn = model.worn[category] {
                    tryOn.takeOff(itemID: worn.id, category: category)
                }
                model.worn[category] = nil
            }
            if let scarf = model.worn[.accessories], scarf.isScarfLike {
                tryOn.takeOff(itemID: scarf.id, category: .accessories)
                model.worn[.accessories] = nil
            }
        default:
            for category in zone.categories {
                if let worn = model.worn[category] {
                    tryOn.takeOff(itemID: worn.id, category: category)
                }
                model.worn[category] = nil
            }
        }
    }

    private func wear(_ item: ClothingItem, in zone: Zone) {
        let category = zone.categories.contains(item.category) ? item.category : zone.category
        if model.worn[category]?.id == item.id {
            clear(zone)
            return
        }
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
                    .background(DSColor.thumbnail, in: RoundedRectangle(cornerRadius: DSRadius.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: DSRadius.md)
                            .stroke(isWorn ? DSColor.brand : .clear, lineWidth: 3)
                    }
                Text(item.name)
                    .font(DSFont.badge)
                    .lineLimit(1)
                    .foregroundStyle(DSColor.textMuted)
                    .frame(width: 76)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.name)
        .accessibilityAddTraits(isWorn ? .isSelected : [])
    }

    private func refreshShareSnapshot() {
        shareSnapshot = renderOutfitShareImage()
    }

  private func renderOutfitShareImage() -> UIImage? {
        if let draft = tryOn.draft,
           draft.compositeDisplayActive,
           let relative = draft.compositeImagePath {
            let url = tryOn.root.appendingPathComponent(relative)
            if let composite = UIImage(contentsOfFile: url.path) {
                return composite
            }
        }
        let renderer = ImageRenderer(
            content: AvatarView(
                look: model.look,
                worn: model.worn,
                image: image,
                uiImage: uiImage,
                use3D: false
            )
            .frame(width: 320, height: 480)
        )
        renderer.scale = 3
        return renderer.uiImage
    }
}

#Preview {
    FullScreenTryOnView(
        model: OutfitStudioModel(),
        tryOn: TryOnEditorModel(ownerId: "preview"),
        items: ClothingItem.previewSamples,
        image: { _ in Image("TablerPhoto") }
    )
}