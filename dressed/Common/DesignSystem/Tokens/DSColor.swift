import SwiftUI

// Values from the dressed-design Figma mockups (closet, for u, friends, share to dressed).
// The mockups are light mode only; dark-mode values are TBD.
enum DSColor {
    // Brand
    static let brand = Color(hex: 0x9D83EB)

    // Text
    static let textPrimary = Color.black
    static let textStrong = Color(hex: 0x222222)
    static let textMuted = Color(hex: 0x808080)
    static let textPlaceholder = Color(hex: 0xBDBDBD)
    static let tabInactive = Color(hex: 0x6D6D6D)

    // Surfaces
    static let background = Color.white
    static let tile = Color(hex: 0xF2F2F2)
    static let thumbnail = Color(hex: 0xF1F1F1)
    static let raised = Color(hex: 0xF8F8F8)
    static let pressed = Color(hex: 0xE9E8E7)
    static let secondaryFill = Color(hex: 0xE5E5E0)
    static let glass = Color.white.opacity(0.85)

    // Strokes
    static let pressedBorder = Color(hex: 0xDDDDDD)
    static let fieldBorder = Color(hex: 0xE0E0E0)
    static let divider = Color(hex: 0xEBEBEB)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
