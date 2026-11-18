import SwiftUI

// Starter for DATA-02 (#54). Selection belongs to the parent review screen.
struct ImportCandidateRow: View {
    let name: String
    let thumbnail: Image
    @Binding var isSelected: Bool

    var body: some View {
        // One accessible button keeps the label and selection control in the same hit target.
        Button {
            isSelected.toggle()
        } label: {
            HStack(spacing: 12) {
                thumbnail
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 72)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)

                Text(name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Spacer()
                DSIcon(isSelected ? "TablerCircleCheckFilled" : "TablerCircle", size: 26)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 44, height: 44)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

#Preview("Selected") {
    @Previewable @State var isSelected = true
    ImportCandidateRow(
        name: "Blue shirt",
        thumbnail: Image("TablerShirt"),
        isSelected: $isSelected
    )
    .padding()
}

#Preview("Unselected") {
    @Previewable @State var isSelected = false
    ImportCandidateRow(
        name: "Blue shirt",
        thumbnail: Image("TablerShirt"),
        isSelected: $isSelected
    )
    .padding()
}
