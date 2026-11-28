import SwiftUI

// Outline text field with a small label above the text: "Outfit Name" on Create Outfit (1273:173).
struct DSLabeledField: View {
    let label: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(DSFont.fieldLabel)
                .foregroundStyle(DSColor.textPrimary)
            TextField("", text: $text, prompt: Text(prompt).foregroundStyle(DSColor.textMuted))
                .font(DSFont.body)
                .tint(DSColor.textPrimary)
        }
        .padding(.horizontal, DSSpacing.md)
        .frame(height: 57)
        .background(
            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                .fill(DSColor.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                        .stroke(DSColor.textPrimary, lineWidth: 1)
                )
        )
    }
}

#Preview {
    @Previewable @State var name = ""
    DSLabeledField(label: "Outfit Name", prompt: "Name your outfit", text: $name)
        .padding(DSSpacing.lg)
}
