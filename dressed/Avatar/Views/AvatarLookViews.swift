import SwiftUI

/// The generated look, centered below the status bar. It loads in like the reference video: a coarse
/// pixel mosaic that refines step by step, then a blur that sharpens. The lower body melts into a soft
/// brand glow, and the image drifts slowly afterwards in place of video.
struct AvatarLookImage: View {
    let image: UIImage

    /// Mosaic widths in pixels, coarse to fine.
    private static let mosaicSteps: [CGFloat] = [8, 14, 24, 40, 64]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mosaic: UIImage?
    @State private var blur: CGFloat = 18
    @State private var drifting = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(DSColor.brand.opacity(0.3))
                .frame(maxWidth: .infinity)
                .frame(height: 260)
                .blur(radius: 50)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 20)

            lookImage
                .mask {
                    LinearGradient(
                        stops: [.init(color: .black, location: 0.62), .init(color: .clear, location: 0.98)],
                        startPoint: .top, endPoint: .bottom
                    )
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement()
        .accessibilityLabel("Your generated look")
        .accessibilityIdentifier("avatar.look")
        .task(id: ObjectIdentifier(image)) { await reveal() }
    }

    private var lookImage: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .blur(radius: blur)
            .overlay {
                if let mosaic {
                    Image(uiImage: mosaic)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .transition(.opacity)
                }
            }
            .scaleEffect(drifting ? 1.03 : 1)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
    }

    private func reveal() async {
        guard !reduceMotion else {
            blur = 0
            return
        }
        for width in Self.mosaicSteps {
            mosaic = Self.downsampled(image, width: width)
            try? await Task.sleep(for: .milliseconds(180))
            if Task.isCancelled { return }
        }
        withAnimation(.easeOut(duration: 0.35)) { mosaic = nil }
        withAnimation(.easeOut(duration: 1.0)) { blur = 0 }
        try? await Task.sleep(for: .seconds(1))
        withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) { drifting = true }
    }

    /// A tiny copy of the image; drawn without interpolation it shows as square pixel blocks.
    private static func downsampled(_ image: UIImage, width: CGFloat) -> UIImage {
        let height = max(1, (width * image.size.height / max(image.size.width, 1)).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}

/// Shown while a look generates (about 20–60 s): the outfit's pieces float on a soft brand glow while a
/// scan line passes over them, with "Pairing the pieces" as in the reference video.
struct AvatarGeneratingView: View {
    let pieces: [ClothingItem]
    let uiImage: (ClothingItem) -> UIImage?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    RadialGradient(
                        colors: [DSColor.brand.opacity(0.28), DSColor.brand.opacity(0.08), DSColor.background],
                        center: .center, startRadius: 0, endRadius: size.height * 0.55
                    )
                    .scaleEffect(1 + 0.06 * sin(time * 1.2))

                    VStack(spacing: DSSpacing.sm) {
                        ForEach(Array(pieces.enumerated()), id: \.element.id) { index, item in
                            pieceImage(item)
                                .frame(height: min(150, size.height * 0.55 / CGFloat(max(pieces.count, 1))))
                                .offset(y: reduceMotion ? 0 : 4 * sin(time * 1.6 + Double(index)))
                        }
                    }
                    .padding(.horizontal, size.width * 0.25)

                    // Scan line sweeping top to bottom.
                    if !reduceMotion {
                        let progress = (time / 2.4).truncatingRemainder(dividingBy: 1)
                        LinearGradient(colors: [DSColor.brand.opacity(0), DSColor.brand.opacity(0.18), DSColor.brand.opacity(0)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(width: size.width * 0.7, height: 60)
                            .overlay { Rectangle().fill(DSColor.brand.opacity(0.5)).frame(height: 1) }
                            .position(x: size.width / 2, y: size.height * (0.15 + 0.7 * progress))
                            .allowsHitTesting(false)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                Label("Pairing the pieces", tabler: "TablerSparkles", size: 16)
                    .font(DSFont.bodyEmphasis)
                    .foregroundStyle(DSColor.textStrong)
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.sm)
                    .background(DSColor.glass, in: Capsule())
                    .padding(.bottom, 110)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Generating your look")
        .accessibilityIdentifier("avatar.generating")
    }

    @ViewBuilder private func pieceImage(_ item: ClothingItem) -> some View {
        if let photo = uiImage(item) {
            Image(uiImage: photo).resizable().scaledToFit()
        } else {
            DSIcon("TablerShirt", size: 48).foregroundStyle(DSColor.iconMuted)
        }
    }
}

#Preview("Generating") {
    AvatarGeneratingView(pieces: ClothingItem.previewSamples, uiImage: { _ in nil })
}
