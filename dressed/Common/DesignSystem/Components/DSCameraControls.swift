import SwiftUI

// Capture bar over the live camera (1012:388): upload from library, shutter, flip camera, inside a
// translucent capsule. The close button above it is `.buttonStyle(.ds(.glass))` with TablerX.
// The mockup flips with an SF Symbol; this uses Tabler Refresh instead.
struct DSCameraControls: View {
    let onUpload: () -> Void
    let onCapture: () -> Void
    let onFlip: () -> Void

    var body: some View {
        HStack {
            sideButton("TablerUpload", fill: DSColor.glass, label: "Upload", action: onUpload)
            Spacer()
            Button(action: onCapture) {
                Circle()
                    .fill(Color.white)
                    .frame(width: 76, height: 76)
                    .padding(5)
                    .overlay(Circle().stroke(Color.white, lineWidth: 3))
                    .frame(width: 90, height: 90)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Take photo")
            Spacer()
            sideButton("TablerRefresh", fill: DSColor.tile, label: "Flip camera", action: onFlip)
        }
        .padding(.horizontal, 27)
        .frame(height: 115)
        .background(
            Capsule()
                .fill(DSColor.cameraBar)
                .overlay(Capsule().stroke(Color.white, lineWidth: 0.25))
        )
    }

    private func sideButton(_ icon: String, fill: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            DSIcon(icon, size: 24)
                .foregroundStyle(icon == "TablerRefresh" ? DSColor.textMuted : DSColor.textPrimary)
                .frame(width: 50, height: 50)
                .background(Circle().fill(fill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.black
        DSCameraControls(onUpload: {}, onCapture: {}, onFlip: {})
            .padding(30)
    }
}
