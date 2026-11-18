import SwiftUI

// 24 pt select circle on Create Outfit tiles (1273:173): black ring, filled black with a check when chosen.
// Selection state belongs to the parent; make the whole tile the tap target.
struct DSSelectionMark: View {
    let isChecked: Bool

    var body: some View {
        ZStack {
            if isChecked {
                Circle().fill(DSColor.textPrimary)
                DSIcon("TablerCheck", size: 17).foregroundStyle(.white)
            } else {
                Circle().stroke(DSColor.textPrimary, lineWidth: 2)
            }
        }
        .frame(width: 24, height: 24)
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
