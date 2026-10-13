import SwiftUI

enum AvatarPart: String, CaseIterable, Identifiable {
    case bangs, hair, face, body
    var id: String { rawValue }
}

extension ClothingCategory {
    /// Back-to-front draw order on the 2D avatar.
    static let layerOrder: [ClothingCategory] = [.pants, .skirts, .dresses, .tops, .outerwear, .shoes]

    /// Where a garment sits on the avatar, as fractions of the avatar's height.
    var avatarSlot: (y: CGFloat, size: CGFloat) {
        switch self {
        case .pants: return (0.66, 0.30)
        case .skirts: return (0.58, 0.22)
        case .dresses: return (0.50, 0.42)
        case .tops: return (0.36, 0.22)
        case .outerwear: return (0.38, 0.28)
        case .shoes: return (0.93, 0.10)
        default: return (0.50, 0.20)
        }
    }
}

// 2D placeholder avatar. Replace the body of this view with a RealityView later.
struct AvatarView: View {
    let look: [AvatarPart: Int]
    let worn: [ClothingCategory: ClothingItem]
    let image: (ClothingItem) -> Image
    var zoom: Double = 1

    static let bodyTints: [Color] = [
        Color(red: 0.96, green: 0.84, blue: 0.74),
        Color(red: 0.89, green: 0.72, blue: 0.58),
        Color(red: 0.78, green: 0.58, blue: 0.43),
        Color(red: 0.55, green: 0.38, blue: 0.28),
        Color(red: 0.36, green: 0.24, blue: 0.18)
    ]

    private var tint: Color {
        guard let index = look[.body] else { return Color.gray.opacity(0.5) }
        return Self.bodyTints[index % Self.bodyTints.count]
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Image(systemName: "figure.stand")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(tint)
                    .frame(height: h * 0.95)
                    .position(x: w / 2, y: h / 2)

                ForEach(ClothingCategory.layerOrder, id: \.self) { category in
                    if let item = worn[category] {
                        let slot = category.avatarSlot
                        image(item)
                            .resizable()
                            .scaledToFit()
                            .frame(width: w * 0.5, height: h * slot.size)
                            .position(x: w / 2, y: h * slot.y)
                    }
                }
            }
            .scaleEffect(zoom, anchor: .top)
        }
        .background(Color(white: 0.93))
        .clipped()
    }
}
