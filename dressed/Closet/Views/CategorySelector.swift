import SwiftUI

// Starter for VIZ-02 (#73). nil means "All"; this view does not filter items.
struct CategorySelector: View {
    @Binding var selection: ClothingCategory?
    
    var body: some View {
        // TODO(#73): Show "All" and ClothingCategory.allCases.
        // Give the selected choice a distinct style and update selection on tap.
        Spacer()
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                let isAllSelected = selection == nil
                Button {
                    selection = nil
                } label: {
                    Text("all")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(isAllSelected ? .blue : .gray.opacity(0.2))
                        .foregroundStyle(isAllSelected ? .white : .primary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(isAllSelected ? .blue : .gray, lineWidth: 2)
                        )
                }
                
                ForEach(ClothingCategory.allCases, id: \.self) { theme in
                    let isSelected = selection == theme

                    Button {
                        selection = theme
                        print(theme.rawValue)
                    } label: {
                        Text(theme.rawValue)
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
