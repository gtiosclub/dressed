import SwiftUI

// "For You / Friends" switch from the Discovery mockups. The thumb springs with a little overshoot.
struct DSSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    @Namespace private var thumb
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.5, dampingFraction: 0.55)) { selection = option }
                } label: {
                    Text(title(option))
                        .font(DSFont.label)
                        .foregroundStyle(isSelected ? DSColor.textPrimary : DSColor.textMuted)
                        .frame(width: 93, height: 34)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(DSColor.raised)
                                    .dsShadow(.raised)
                                    .matchedGeometryEffect(id: "thumb", in: thumb)
                            }
                        }
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: selection)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(DSColor.pressed.shadow(DSShadow.pressedInner))
                .overlay(Capsule().stroke(DSColor.pressedBorder, lineWidth: 1))
        }
    }
}

#Preview {
    @Previewable @State var selection = "For You"
    DSSegmentedControl(options: ["For You", "Friends"], selection: $selection) { $0 }
        .padding()
        .background(DSColor.background)
}
