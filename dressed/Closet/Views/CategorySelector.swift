import SwiftUI

// Starter for VIZ-02 (#73). nil means "All"; this view does not filter items.
struct CategorySelector: View {
    @Binding var selection: ClothingCategory?
    
    var body: some View {
        // TODO(#73): Show "All" and ClothingCategory.allCases.
        // Give the selected choice a distinct style and update selection on tap.
        Spacer()
        let clothingChoices: [ClothingCategory?] = [nil] + ClothingCategory.allCases
        
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 8) {
                ForEach(clothingChoices, id: \.self) { type in
                    let isSelected = selection == type
                    Button {
                        selection = type
                    } label: {
                        Text(type?.rawValue ?? "all")
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isSelected ? .blue : .gray.opacity(0.2))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(isSelected ? .blue : .gray, lineWidth: 2)
                            )
                    }

                }
            }
            .padding(.horizontal)
        }
        
    }
}

#Preview {
    @Previewable @State var selection: ClothingCategory? = .tops
    CategorySelector(selection: $selection)
}
