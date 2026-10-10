import SwiftUI

// Starter for DATA-01 (#52). The parent screen owns the photo picker.
struct ChoosePhotoButton: View {
    let onPhotoLibrary: () -> Void

    var body: some View {
        // TODO(#52): Show a button with a photo icon and "Choose photo".
        // Call onPhotoLibrary once when it is tapped.
        EmptyView()
    }
}

#Preview {
    ChoosePhotoButton(onPhotoLibrary: {})
}
