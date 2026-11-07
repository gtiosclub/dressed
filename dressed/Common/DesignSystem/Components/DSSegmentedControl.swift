import SwiftUI

// "For You / Friends" switch from the Discovery mockups.
struct DSSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.snappy) { selection = option }
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
