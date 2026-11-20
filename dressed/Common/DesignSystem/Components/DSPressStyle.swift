import SwiftUI

// Press feedback for tappable surfaces that draw their own look (chips, tiles, pills, circle buttons):
// a quick spring scale-down on touch, released with a little overshoot. With Reduce Motion on, it dims instead.
struct DSPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DSPressStyle {
    /// Press feedback for custom-drawn controls. Use `.dsPress(0.985)` on large tiles for a subtler dip.
    static var dsPress: DSPressStyle { DSPressStyle() }
    static func dsPress(_ scale: CGFloat) -> DSPressStyle { DSPressStyle(scale: scale) }
}
