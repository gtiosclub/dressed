import SwiftUI

// Figma blur values are halved to get SwiftUI radii. Figma spread has no SwiftUI equivalent.
struct DSShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let none = DSShadow(color: .clear, radius: 0, x: 0, y: 0)
    static let raised = DSShadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 2)       // chips, segment thumb
    // Compact glass controls need a centered halo; a vertical offset makes their capsule look displaced.
    static let controlRaised = DSShadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 0)
    static let floating = DSShadow(color: .black.opacity(0.25), radius: 25, x: 0, y: 4)    // search bar
    static let card = DSShadow(color: .black.opacity(0.1), radius: 5, x: 1, y: 1)          // list rows
    static let brandGlow = DSShadow(color: DSColor.brand.opacity(0.25), radius: 5, x: 0, y: 4) // post card

    static let selectedGlow = DSShadow(color: DSColor.brandLight.opacity(0.3), radius: 30, x: 1, y: 1) // selected closet tile
    static let selectedRow = DSShadow(color: DSColor.brandLight.opacity(0.5), radius: 5, x: 1, y: 1)   // selected candidate row

    // Inner shadows for pressed and recessed surfaces.
    static let pressedInner = ShadowStyle.inner(color: .black.opacity(0.4), radius: 1, x: 0, y: 2)
    static let recessedInner = ShadowStyle.inner(color: .black.opacity(0.1), radius: 5, x: 0, y: 1)
}

extension View {
    func dsShadow(_ shadow: DSShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
