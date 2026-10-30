import SwiftUI

struct ClothingItemCard: View {
    private let thumbnail: AnyView
    let name: String
    let category: ClothingCategory
    var subtitle: String?  // replaces the category label when set
    let onTap: () -> Void

    init(image: Image, name: String, category: ClothingCategory, subtitle: String? = nil, onTap: @escaping () -> Void) {
        self.thumbnail = AnyView(image.resizable().scaledToFit())
        self.name = name
        self.category = category
        self.subtitle = subtitle
        self.onTap = onTap
    }

    init(thumbnail: AnyView, name: String, category: ClothingCategory, subtitle: String? = nil, onTap: @escaping () -> Void) {
        self.thumbnail = thumbnail
        self.name = name
        self.category = category
        self.subtitle = subtitle
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                thumbnail
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .accessibilityHidden(true)

                Text(name)
                    .font(.headline)
                    .lineLimit(2)

                Text(subtitle ?? category.rawValue.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(width: 180, alignment: .leading)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

private struct ClothingItemCardPreview: View {
    @State private var taps = 0

    var body: some View {
        VStack(spacing: 16) {
            ClothingItemCard(
                image: Image(systemName: "photo"),
                name: "Blue shirt",
                category: .tops,
                onTap: {
                    taps += 1
                }
            )

            Text("Taps: \(taps)")
        }
    }
}
