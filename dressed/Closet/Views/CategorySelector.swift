import SwiftUI

// Starter for VIZ-02 (#73). nil means "All"; this view does not filter items.
struct CategorySelector: View {
    @Binding var selection: ClothingCategory?
    var body: some View {
        let clothingChoices: [ClothingCategory?] = [nil] + ClothingCategory.allCases
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 8) {
                ForEach(clothingChoices, id: \.self) { type in
                    let isSelected = selection == type
                    Button {
                        selection = type
                    } label: {
                        if isSelected {
                            Label(type?.rawValue ?? "All", systemImage: "checkmark").plumEditorialChip(isSelected: true)
                        } else {
                            Text(type?.rawValue ?? "All").plumEditorialChip(isSelected: isSelected)
                        }
                    }

                }
            }
            .padding(.horizontal)
        }
    }
}

// DIFFERENT STYLES FOR BUTTONS
private extension View {
    func plumEditorialChip(isSelected: Bool) -> some View {
        self
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .foregroundStyle(
                isSelected
                    ? .white
                    : Color(red: 0.27, green: 0.10, blue: 0.24)
            )
            .background(
                isSelected
                    ? Color(red: 0.28, green: 0.08, blue: 0.24)
                    : Color(red: 0.94, green: 0.89, blue: 0.95)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(
                    isSelected
                        ? Color(red: 0.80, green: 0.66, blue: 0.36)
                        : Color(red: 0.65, green: 0.55, blue: 0.68),
                    lineWidth: isSelected ? 2 : 1
                )
            )
    }
}

#Preview {
    @Previewable @State var selection: ClothingCategory? = .tops
    CategorySelector(selection: $selection)
}
