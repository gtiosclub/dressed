import SwiftUI

// Starter for VIZ-02 (#73). nil means "All"; this view does not filter items.
struct CategorySelector: View {
    @Binding var selection: ClothingCategory?
    
    var body: some View {
        // TODO(#73): Show "All" and ClothingCategory.allCases.
        // Give the selected choice a distinct style and update selection on tap.
        ForEach(ClothingCategory.allCases, id: \.self) { theme in
            let isSelected = selection == theme

            Button {
                selection = theme
                print(theme.rawValue)
            } label: {
                Text(theme.rawValue)
                    .padding()
                    .background(isSelected ? .blue : .red)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }

        }
        let isAllSelected = selection == nil
        Button {
            selection = nil
        } label: {
            Text("all")
                .padding()
                .background(isAllSelected ? .blue : .red)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
        
        
        
    }
}

#Preview {
    CategorySelector(selection: .constant(.tops))
}
