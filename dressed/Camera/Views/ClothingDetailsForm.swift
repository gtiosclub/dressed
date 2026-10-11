import SwiftUI

/// Collects manual details; the parent owns persistence and photo handling.
struct ClothingDetailsForm: View {
    @Binding var name: String
    @Binding var category: ClothingCategory
    let onSave: (String, ClothingCategory) -> Void

    var body: some View {
        Form {
            TextField("Name", text: $name)
                .accessibilityIdentifier("clothing-name")

            Picker("Category", selection: $category) {
                ForEach(ClothingCategory.allCases, id: \.self) { option in
                    Text(option.rawValue.capitalized).tag(option)
                }
            }
            .accessibilityIdentifier("clothing-category")

            Button("Save") {
                onSave(name, category)
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("save-clothing-details")
        }
    }
}

#Preview {
    @Previewable @State var name = "Blue shirt"
    @Previewable @State var category = ClothingCategory.tops
    ClothingDetailsForm(name: $name, category: $category, onSave: { _, _ in })
}
