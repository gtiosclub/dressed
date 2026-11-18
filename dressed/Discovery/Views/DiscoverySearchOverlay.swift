import SwiftUI

/// Search mode for Discovery (Figma 976:162 pattern): the whole screen dims, with suggestions above the field.
/// Choosing a suggestion or submitting hands the query to `onSearch`, which opens the catalog search results.
struct DiscoverySearchOverlay: View {
    let onSearch: (String) -> Void
    let onClose: () -> Void

    @State private var query = ""

    private static let styles = ["Y2K", "Colorful", "Trendy", "Comfortable", "Monotone", "Vintage", "Minimal", "Streetwear"]

    private var suggestions: [String] {
        let typed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return Array(Self.styles.prefix(4)) }
        let matches = Self.styles.filter { $0.localizedCaseInsensitiveContains(typed) && $0.caseInsensitiveCompare(typed) != .orderedSame }
        return Array(([typed] + matches).prefix(4))
    }

    var body: some View {
        DSSearchSheet(
            prompt: "Search Styles",
            query: $query,
            suggestions: suggestions,
            onSelect: submit,
            onSubmit: { submit(query) },
            onClose: onClose
        )
    }

    private func submit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSearch(trimmed)
    }
}
