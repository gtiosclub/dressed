import SwiftUI

// Fixed sizes match the mockups; they do not scale with Dynamic Type yet.
enum DSFont {
    static let label = Font.system(size: 16)                  // chips, segmented control
    static let bodyEmphasis = Font.system(size: 16, weight: .medium) // titles, handles, counts
    static let body = Font.system(size: 16)                   // subtitles
    static let button = Font.system(size: 14, weight: .medium)
    static let search = Font.system(size: 13, weight: .medium)
    static let tab = Font.system(size: 10)
    static let badge = Font.system(size: 11)                  // New, 3 of 3
    static let fieldLabel = Font.system(size: 10)             // floating label above a text field
    static let navTitle = Font.system(size: 20)               // Outfit Name, Select Items

    static let lineHeight: CGFloat = 22
    // System-font glyphs sit slightly below the optical center of compact capsules.
    static let controlLabelOpticalOffset: CGFloat = -1
}
