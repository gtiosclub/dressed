import SwiftUI

// Starter for DATA-02 (#54). Selection belongs to the parent review screen.
struct ImportCandidateRow: View {
    let name: String
    let thumbnail: Image
    @Binding var isSelected: Bool

    var body: some View {
        // TODO(#54): Show the supplied image and name with a selection control.
        // The control changes isSelected; this row does not save or upload.
        EmptyView()
    }
}

#Preview("Selected") {
    ImportCandidateRow(
        name: "Blue shirt",
        thumbnail: Image(systemName: "photo"),
        isSelected: .constant(true)
    )
}

#Preview("Unselected") {
    ImportCandidateRow(
        name: "Blue shirt",
        thumbnail: Image(systemName: "photo"),
        isSelected: .constant(false)
    )
}
