import Foundation

/// Fitting templates selected by the user from the closet item's existing category.
/// This file does not score a new category.
enum TryOnTemplateID: String, Codable, CaseIterable, Identifiable {
    case tShirt = "tshirt_v1"
    case oversizedHoodie = "oversized_hoodie_v1"
    case openJacket = "open_jacket_v1"
    case trousers = "trousers_v1"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tShirt: return "T-shirt"
        case .oversizedHoodie: return "Oversized hoodie"
        case .openJacket: return "Open jacket"
        case .trousers: return "Trousers"
        }
    }

    /// A starting template from the category already stored on the closet item.
    static func suggested(for category: ClothingCategory) -> TryOnTemplateID? {
        switch category {
        case .tops: return .tShirt
        case .outerwear: return .openJacket
        case .pants: return .trousers
        default: return nil
        }
    }

    var split: TryOnSplitStyle {
        switch self {
        case .tShirt: return .top
        case .oversizedHoodie: return .hoodie
        case .openJacket: return .openJacket
        case .trousers: return .trousers
        }
    }

    var preserveSilhouette: Bool { self == .oversizedHoodie }

    var fitStyle: String {
        switch self {
        case .tShirt: return "standard"
        case .oversizedHoodie: return "oversized"
        case .openJacket: return "open"
        case .trousers: return "trouser"
        }
    }

    var requiredAnchors: [String] {
        switch self {
        case .tShirt, .oversizedHoodie:
            return ["necklineCenter", "leftShoulderSeam", "rightShoulderSeam", "hemCenter"]
        case .openJacket:
            return ["necklineCenter", "leftShoulderSeam", "rightShoulderSeam", "hemCenter"]
        case .trousers:
            return ["waistCenter", "leftHip", "rightHip", "crotchCenter"]
        }
    }

    /// Garment anchor paired with the first avatar landmark that was actually detected.
    var alignmentLinks: [(garment: String, avatar: [String])] {
        switch self {
        case .tShirt, .oversizedHoodie, .openJacket:
            return [
                ("necklineCenter", ["neckCenter"]),
                ("leftShoulderSeam", ["leftShoulderEdge", "leftShoulderJoint"]),
                ("rightShoulderSeam", ["rightShoulderEdge", "rightShoulderJoint"])
            ]
        case .trousers:
            return [
                ("waistCenter", ["waistCenter"]),
                ("leftHip", ["leftHip"]),
                ("rightHip", ["rightHip"])
            ]
        }
    }

    var promptRules: String {
        switch self {
        case .tShirt:
            return """
            Align the neckline with the avatar neck. Leave a transparent elliptical neck opening — do not paint \
            skin or collar filling the hole. Sleeves are fabric tubes only; keep each cuff opening transparent \
            so hands and wrists are NOT part of the garment PNG. Do not extend opaque fabric above the shoulder \
            line or over the face. Align shoulder seams to the shoulder region. Keep the source torso width and \
            hem length (kurta, shirt, or tee). Protect chest graphics and lettering from distortion.
            """
        case .oversizedHoodie:
            return """
            Preserve dropped shoulders, sleeve volume, extra torso width, and a longer hem. \
            Do not shrink the hoodie to the body outline. Keep the hood as part of the garment, \
            with space for the head. Protect logos, prints, drawstrings, the pocket, and seams.
            """
        case .openJacket:
            return """
            Keep the center front opening fully transparent. Do not paint a shirt, skin, or lining \
            into that opening. Keep lapels, the zipper or buttons, and the open state. \
            Left and right front panels must remain separate fabric around the empty center.
            """
        case .trousers:
            return """
            Keep the left and right legs separate. Preserve the leg width and cut. \
            Do not collapse the crotch or merge the legs. Keep the waistband shape.
            """
        }
    }
}

enum TryOnSplitStyle: String, Codable {
    case single
    case top
    case hoodie
    case openJacket
    case trousers
}

enum TryOnStack {
    static func rank(for category: ClothingCategory) -> Int {
        switch category {
        case .pants: return 0
        case .skirts: return 1
        case .dresses: return 2
        case .tops: return 3
        case .outerwear: return 4
        case .shoes: return 5
        case .accessories, .other: return 3
        }
    }
}
