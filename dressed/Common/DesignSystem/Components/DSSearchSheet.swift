import SwiftUI

// Search mode from the closet mockup (976:162): dimmed backdrop, close button top-left, white suggestion
// sheet with the pill field pinned below it (the keyboard sits under the field). The caller owns the query,
// suggestions and results, and presents this over the screen.
struct DSSearchSheet: View {
    let prompt: String
    @Binding var query: String
    let suggestions: [String]
    let onSelect: (String) -> Void
    let onSubmit: () -> Void
    let onClose: () -> Void

    @FocusState private var focused: Bool
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .topLeading) {
            DSColor.scrim.ignoresSafeArea().opacity(appeared ? 1 : 0)

            Button(action: onClose) {
                DSIcon("TablerX", size: 24)
                    .foregroundStyle(DSColor.textPrimary)
                    .frame(width: 50, height: 50)
                    .background(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous).fill(DSColor.background))
            }
            .buttonStyle(.dsPress)
            .padding(.leading, 9)
            .padding(.top, DSSpacing.sm)
            .accessibilityLabel("Close search")

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button { onSelect(suggestion) } label: {
                                HStack(spacing: DSSpacing.md) {
                                    DSIcon("TablerSearch", size: 13)
                                    Text(suggestion).font(DSFont.button)
                                }
                                .foregroundStyle(DSColor.textPrimary)
                            }
                            .buttonStyle(.dsPress(0.98))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 23)
                    .padding(.top, 23)
                    .padding(.bottom, DSSpacing.lg)

                    field
                        .padding(.horizontal, 9)
                        .padding(.bottom, DSSpacing.sm)
                }
                .background(
                    // Fills down to the screen edge; the keyboard still pushes the field up.
                    UnevenRoundedRectangle(topLeadingRadius: DSRadius.lg, topTrailingRadius: DSRadius.lg)
                        .fill(DSColor.background)
                        .ignoresSafeArea(.container, edges: .bottom)
                )
                .offset(y: appeared || reduceMotion ? 0 : 48)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            focused = true
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { appeared = true }
        }
    }

    private var field: some View {
        TextField("", text: $query, prompt: Text(prompt).foregroundStyle(DSColor.textMuted))
            .font(DSFont.search)
            .tint(DSColor.textPrimary)
            .focused($focused)
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
    DSSearchSheet(prompt: "Search Your Closet", query: $query,
                  suggestions: ["Lorem Ipsum", "Lorem Ipsum", "Lorem Ipsum", "Lorem Ipsum"],
                  onSelect: { _ in }, onSubmit: {}, onClose: {})
}
