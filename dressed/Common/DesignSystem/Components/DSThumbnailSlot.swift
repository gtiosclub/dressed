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

// White-bordered frame that marks the detected piece on the source photo.
struct DSCropFrame: View {
    var body: some View {
        RoundedRectangle(cornerRadius: DSRadius.xl, style: .continuous)
            .strokeBorder(Color.white, lineWidth: 5)
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
        DSCropFrame().frame(width: 210, height: 206)
    }
    .frame(height: 385)
    .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
    .padding(9)
}
