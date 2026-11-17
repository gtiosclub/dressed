import SwiftUI

// Figma blur values are halved to get SwiftUI radii. Figma spread has no SwiftUI equivalent.
struct DSShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let raised = DSShadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 2)       // chips, segment thumb
    static let floating = DSShadow(color: .black.opacity(0.25), radius: 25, x: 0, y: 4)    // search bar
    static let card = DSShadow(color: .black.opacity(0.1), radius: 5, x: 1, y: 1)          // list rows
    static let brandGlow = DSShadow(color: DSColor.brand.opacity(0.25), radius: 5, x: 0, y: 4) // post card

    // Inner shadows for pressed and recessed surfaces.
    static let pressedInner = ShadowStyle.inner(color: .black.opacity(0.4), radius: 1, x: 0, y: 2)
    static let recessedInner = ShadowStyle.inner(color: .black.opacity(0.1), radius: 5, x: 0, y: 1)
}

extension View {
    func dsShadow(_ shadow: DSShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
