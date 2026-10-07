import SwiftUI

struct ClothingItemCard: View {
    let image: Image
    let name: String
    let category: ClothingCategory
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)

                Text(name)
                    .font(.headline)
                    .lineLimit(2)

                Text(category.rawValue.capitalized)
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

#Preview {
    ClothingItemCardPreview()
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

