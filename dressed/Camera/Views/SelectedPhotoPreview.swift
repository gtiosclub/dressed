import SwiftUI

/// Displays a selected photo with Replace and Cancel actions.
/// The parent owns photo selection and import state; this view only reports taps.
struct SelectedPhotoPreview: View {
    let image: UIImage
    let onReplace: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Selected photo")

            HStack(spacing: 12) {
                Button("Cancel", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                Button("Replace", action: onReplace)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
}

#if DEBUG
#Preview {
    // Local sample image: no Firebase or photo-library access.
    // Uses an SF Symbol rendered to a UIImage so no asset is required.
    // Swap in UIImage(named: "SampleShirt") if you add one to the asset catalog.
    let sample = UIImage(systemName: "tshirt.fill")?
        .withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
        ?? UIImage()

    return SelectedPhotoPreview(
        image: sample,
        onReplace: { print("Replace tapped") },
        onCancel: { print("Cancel tapped") }
    )
}
#endif
