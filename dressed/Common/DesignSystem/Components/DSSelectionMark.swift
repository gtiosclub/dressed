import SwiftUI

// 24 pt select circle on Create Outfit tiles (1273:173): black ring, filled black with a check when chosen.
// Selection state belongs to the parent; make the whole tile the tap target.
struct DSSelectionMark: View {
    let isChecked: Bool

    var body: some View {
        ZStack {
            Circle().stroke(DSColor.textPrimary, lineWidth: 2)
            Circle()
                .fill(DSColor.textPrimary)
                .scaleEffect(isChecked ? 1 : 0.4)
                .opacity(isChecked ? 1 : 0)
            DSIcon("TablerCheck", size: 17)
                .foregroundStyle(.white)
                .scaleEffect(isChecked ? 1 : 0.3)
                .opacity(isChecked ? 1 : 0)
        }
        .frame(width: 24, height: 24)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isChecked)
        .sensoryFeedback(.selection, trigger: isChecked)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: DSSpacing.lg) {
        DSSelectionMark(isChecked: false)
        DSSelectionMark(isChecked: true)
    }
    .padding()
}
