import SwiftUI

// 50 pt recessed slot for pieces queued in the share flow's bottom bar.
struct DSThumbnailSlot<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        RoundedRectangle(cornerRadius: DSRadius.xs)
            .fill(DSColor.thumbnail.shadow(DSShadow.recessedInner))
            .frame(width: 50, height: 50)
            .overlay { content().padding(DSSpacing.xs) }
    }
}

// Frame that marks the detected piece on the source photo: white while browsing,
// brand purple once a candidate is selected (777:6352 vs 1012:282).
struct DSCropFrame: View {
    var color: Color = .white

    var body: some View {
        RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous)
            .strokeBorder(color, lineWidth: 5)
    }
}

#Preview("Thumbnail slots") {
    HStack(spacing: DSSpacing.xs) {
        Button("Back") {}.buttonStyle(.ds(.secondary)).frame(width: 81)
        DSThumbnailSlot {
            Image("PreviewJeans").resizable().scaledToFit()
        }
        DSThumbnailSlot {
            Image("PreviewNecklace").resizable().scaledToFit()
        }
        Spacer()
    }
    .padding(13)
}

#Preview("Crop frame") {
    ZStack {
        DSColor.textMuted
        HStack {
            DSCropFrame().frame(width: 150, height: 146)
            DSCropFrame(color: DSColor.brand).frame(width: 150, height: 146)
        }
    }
    .frame(height: 385)
    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
    .padding(9)
}
