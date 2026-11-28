import SwiftUI

// The bordered, floating pill search field from the closet search sheet (976:162).
struct DSSearchField: View {
    let prompt: String
    @Binding var query: String
    var onSubmit: () -> Void = {}

    var body: some View {
        TextField("", text: $query, prompt: Text(prompt).foregroundStyle(DSColor.textMuted))
            .font(DSFont.search)
            .tint(DSColor.textPrimary)
            .submitLabel(.search)
            .onSubmit(onSubmit)
            .padding(.horizontal, DSSpacing.lg)
            .frame(height: DSFloatingSearchButton.height)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .fill(DSColor.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                            .stroke(DSColor.fieldBorder, lineWidth: 1)
                    )
                    .dsShadow(.floating)
            )
    }
}

#Preview {
    @Previewable @State var query = ""
    DSSearchField(prompt: "Search products", query: $query)
        .padding()
}
