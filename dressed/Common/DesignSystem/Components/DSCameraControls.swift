import SwiftUI

// Capture bar over the live camera (1012:388): upload from library, shutter, flip camera, inside a
// translucent capsule. The close button above it is `.buttonStyle(.ds(.glass))` with TablerX.
// The mockup flips with an SF Symbol; this uses Tabler Refresh instead.
struct DSCameraControls: View {
    let onUpload: () -> Void
    let onCapture: () -> Void
    let onFlip: () -> Void

    @State private var captures = 0
    @State private var flips = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack {
            sideButton("TablerUpload", fill: DSColor.glass, label: "Upload", action: onUpload)
            Spacer()
            Button {
                captures += 1
                onCapture()
            } label: {
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 90, height: 90)
                    .overlay { Circle().fill(Color.white).frame(width: 76, height: 76) }
            }
            .buttonStyle(ShutterStyle())
            .sensoryFeedback(.impact(weight: .medium), trigger: captures)
            .accessibilityLabel("Take photo")
            Spacer()
            sideButton("TablerRefresh", fill: DSColor.tile, label: "Flip camera") {
                flips += 1
                onFlip()
            }
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
                .rotationEffect(.degrees(icon == "TablerRefresh" && !reduceMotion ? Double(flips) * 180 : 0))
                .animation(.spring(response: 0.45, dampingFraction: 0.7), value: flips)
                .frame(width: 50, height: 50)
                .background(Circle().fill(fill))
        }
        .buttonStyle(.dsPress)
        .sensoryFeedback(.selection, trigger: flips)
        .accessibilityLabel(label)
    }
}

// The inner disc dips on touch, like the system camera's shutter.
private struct ShutterStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.92 : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        Color.black
        DSCameraControls(onUpload: {}, onCapture: {}, onFlip: {})
            .padding(30)
    }
}
