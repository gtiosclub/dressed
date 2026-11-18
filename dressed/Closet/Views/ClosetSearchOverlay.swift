import SwiftUI

/// Closet search mode (Figma 976:162): the whole screen dims, with matching piece and outfit names above the field.
/// An empty submit clears the current search.
struct ClosetSearchOverlay: View {
    let names: [String]
    let onSearch: (String) -> Void
    let onClose: () -> Void

    @State private var query: String

    init(initialQuery: String, names: [String], onSearch: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.names = names
        self.onSearch = onSearch
        self.onClose = onClose
        _query = State(initialValue: initialQuery)
    }

    private var suggestions: [String] {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var unique: [String] = []
        for name in names where !unique.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            unique.append(name)
        }
        guard !typed.isEmpty else { return Array(unique.prefix(4)) }
        let matches = unique.filter { $0.localizedCaseInsensitiveContains(typed) && $0.caseInsensitiveCompare(typed) != .orderedSame }
        return Array(([typed] + matches).prefix(4))
    }

    var body: some View {
        DSSearchSheet(
            prompt: "Search Your Closet",
            query: $query,
            suggestions: suggestions,
            onSelect: { onSearch($0) },
            onSubmit: { onSearch(query.trimmingCharacters(in: .whitespacesAndNewlines)) },
            onClose: onClose
        )
    }
}
