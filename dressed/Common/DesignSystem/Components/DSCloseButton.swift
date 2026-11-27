import SwiftUI

// The camera's close control (1012:388): a 50 pt glass rounded square with a 24 pt X,
// shared by the camera, piece review and search screens.
struct DSCloseIcon: View {
    var body: some View {
        DSIcon("TablerX", size: 24).foregroundStyle(DSColor.iconMuted)
    }
}

struct DSCloseButton: View {
    var accessibilityLabel = "Close"
    let action: () -> Void

    var body: some View {
        Button(action: action) { DSCloseIcon() }
            .buttonStyle(.ds(.glass))
            .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    ZStack {
        DSColor.textMuted
        DSCloseButton {}
    }
    .frame(height: 100)
}
