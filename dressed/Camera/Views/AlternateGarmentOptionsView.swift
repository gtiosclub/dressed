import SwiftUI

/// Searchable category chooser for correcting one detected garment.
/// The parent supplies the categories and owns the clothing name (details form)
/// and saving. This view only reports a chosen category or a manual-entry request.
struct ManualCategorySearchView: View {
    let categories: [ClothingCategory]
    let displayName: (ClothingCategory) -> String
    let onSelect: (ClothingCategory) -> Void
    let onManualEntry: () -> Void

    @State private var query = ""

    init(
        categories: [ClothingCategory] = Array(ClothingCategory.allCases),
        displayName: @escaping (ClothingCategory) -> String = { String(describing: $0).capitalized },
        onSelect: @escaping (ClothingCategory) -> Void,
        onManualEntry: @escaping () -> Void
    ) {
        self.categories = categories
        self.displayName = displayName
        self.onSelect = onSelect
        self.onManualEntry = onManualEntry
    }

    /// Case-insensitive match on the category name. Empty query shows everything.
    private var matches: [ClothingCategory] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return categories }
        return categories.filter { displayName($0).localizedCaseInsensitiveContains(trimmed) }
    }

    var body: some View {
        VStack(spacing: 12) {
            searchField

            List {
                if matches.isEmpty {
                    Text("No matching categories")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(matches, id: \.self) { category in
                        Button {
                            onSelect(category)
                        } label: {
                            Text(displayName(category))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)

            Button(action: onManualEntry) {
                Text("Don't see it? Enter manually")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search categories", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top)
    }
}

#if DEBUG
#Preview {
    ManualCategorySearchView(
        onSelect: { print("Selected \($0)") },
        onManualEntry: { print("Manual entry") }
    )
}
#endif
