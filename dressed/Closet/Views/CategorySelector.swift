import SwiftUI

// Starter for VIZ-02 (#73). nil means "All"; this view does not filter items.
struct CategorySelector: View {
    @Binding var selection: ClothingCategory?

    var body: some View {
        // TODO(#73): Show "All" and ClothingCategory.allCases.
        // Give the selected choice a distinct style and update selection on tap.
        EmptyView()
    }
}

#Preview {
    CategorySelector(selection: .constant(.tops))
}
