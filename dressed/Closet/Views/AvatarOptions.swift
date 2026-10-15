import SwiftUI

// Choices on the avatar customization screen. The shapes behind them live in Mannequin.swift.

enum AvatarPart: String, CaseIterable, Identifiable {
    case bangs, hair, color, face, body, skin
    var id: String { rawValue }
}

enum AvatarPalette {
    static let skin: [UIColor] = [
        UIColor(red: 0.98, green: 0.87, blue: 0.78, alpha: 1),
        UIColor(red: 0.95, green: 0.80, blue: 0.68, alpha: 1),
        UIColor(red: 0.89, green: 0.72, blue: 0.58, alpha: 1),
        UIColor(red: 0.80, green: 0.62, blue: 0.46, alpha: 1),
        UIColor(red: 0.69, green: 0.50, blue: 0.36, alpha: 1),
        UIColor(red: 0.55, green: 0.38, blue: 0.27, alpha: 1),
        UIColor(red: 0.42, green: 0.28, blue: 0.20, alpha: 1),
        UIColor(red: 0.30, green: 0.20, blue: 0.15, alpha: 1)
    ]
    // black, dark brown, chestnut, auburn, blonde, platinum, ginger, gray
    static let hair: [UIColor] = [
        UIColor(red: 0.08, green: 0.07, blue: 0.07, alpha: 1),
        UIColor(red: 0.22, green: 0.13, blue: 0.09, alpha: 1),
        UIColor(red: 0.36, green: 0.21, blue: 0.12, alpha: 1),
        UIColor(red: 0.55, green: 0.22, blue: 0.12, alpha: 1),
        UIColor(red: 0.86, green: 0.70, blue: 0.40, alpha: 1),
        UIColor(red: 0.93, green: 0.90, blue: 0.82, alpha: 1),
        UIColor(red: 0.78, green: 0.35, blue: 0.15, alpha: 1),
        UIColor(red: 0.60, green: 0.60, blue: 0.62, alpha: 1)
    ]

    /// The mannequin stays light: each skin tone is a subtle tint over porcelain white.
    static let mannequin: [UIColor] = AvatarPalette.skin.map {
        AvatarPalette.blend(AvatarPalette.porcelain, toward: $0, amount: 0.45)
    }

    private static let porcelain = UIColor(red: 0.95, green: 0.94, blue: 0.92, alpha: 1)

    private static func blend(_ base: UIColor, toward color: UIColor, amount: CGFloat) -> UIColor {
        var baseRed: CGFloat = 0, baseGreen: CGFloat = 0, baseBlue: CGFloat = 0, baseAlpha: CGFloat = 0
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        base.getRed(&baseRed, green: &baseGreen, blue: &baseBlue, alpha: &baseAlpha)
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return UIColor(
            red: baseRed + (red - baseRed) * amount,
            green: baseGreen + (green - baseGreen) * amount,
            blue: baseBlue + (blue - baseBlue) * amount,
            alpha: 1
        )
    }
}

extension AvatarPart {
    var title: String {
        switch self {
        case .bangs: return "Bangs"
        case .hair: return "Hair"
        case .color: return "Color"
        case .face: return "Face"
        case .body: return "Body"
        case .skin: return "Skin"
        }
    }

    var optionCount: Int {
        switch self {
        case .bangs: return BangsStyle.allCases.count
        case .hair: return HairStyle.allCases.count
        case .color: return AvatarPalette.hair.count
        case .face: return FaceShape.presets.count
        case .body: return BodyShape.presets.count
        case .skin: return AvatarPalette.mannequin.count
        }
    }

    /// The option the avatar wears before the user picks one.
    var defaultIndex: Int {
        switch self {
        case .hair: return HairStyle.short.rawValue
        case .color, .skin: return 2
        case .bangs, .face, .body: return 0
        }
    }

    /// The chosen option, or the default when none is set.
    func selection(in look: [AvatarPart: Int]) -> Int {
        (look[self] ?? defaultIndex) % optionCount
    }

    /// Color swatch for options that are colors; nil for options that need a text label.
    func swatch(_ index: Int) -> Color? {
        switch self {
        case .color: return Color(uiColor: AvatarPalette.hair[index % AvatarPalette.hair.count])
        case .skin: return Color(uiColor: AvatarPalette.mannequin[index % AvatarPalette.mannequin.count])
        case .bangs, .hair, .face, .body: return nil
        }
    }

    func label(_ index: Int) -> String {
        switch self {
        case .bangs: return BangsStyle(rawValue: index)?.title ?? ""
        case .hair: return HairStyle(rawValue: index)?.title ?? ""
        case .face: return FaceShape.presets[index % FaceShape.presets.count].name
        case .body: return BodyShape.presets[index % BodyShape.presets.count].name
        case .color, .skin: return ""
        }
    }
}
