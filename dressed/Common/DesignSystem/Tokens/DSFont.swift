import SwiftUI

// Fixed sizes match the mockups; they do not scale with Dynamic Type yet.
enum DSFont {
    static let label = Font.system(size: 16)                  // chips, segmented control
    static let bodyEmphasis = Font.system(size: 16, weight: .medium) // titles, handles, counts
    static let body = Font.system(size: 16)                   // subtitles
    static let button = Font.system(size: 14, weight: .medium)
    static let search = Font.system(size: 13, weight: .medium)
    static let tab = Font.system(size: 10)

    static let lineHeight: CGFloat = 22
}
