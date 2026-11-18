import SwiftUI

/// Individual public catalog pieces. Outfit posts live in OOTDFeedView.
struct DiscoveryIdeasView: View {
    @StateObject private var model: CatalogViewModel
    @State private var query = ""
    @State private var submittedQuery = ""
    @State private var selectedStyles: [String] = []
    @State private var dismissedStyles: Set<String> = []
    @State private var isSearchFocused = false
    private let usesDemoStyles: Bool

    private let columns = [GridItem(.flexible(), spacing: DSSpacing.md), GridItem(.flexible(), spacing: DSSpacing.md)]
    private let styles = ["Y2K", "Colorful", "Trendy", "Comfortable", "Monotone", "Vintage", "Minimal", "Streetwear"]

    init(service: any CatalogSearching = DiscoveryCatalogSource.current) {
        _model = StateObject(wrappedValue: CatalogViewModel(service: service))
        usesDemoStyles = service is DemoCatalogService
    }

    var body: some View {
        VStack(spacing: 0) {
            // The mockup keeps search in a floating button; the field appears only while searching.
            if isSearchFocused {
                DiscoveryIdeasSearchField(
                    query: $query,
                    selectedStyles: selectedStyles,
                    isFocused: $isSearchFocused,
                    onRemoveStyle: removeStyle,
                    onSubmit: submitSearch,
                    onClear: clearSearch
                )
                .padding(.horizontal, DSSpacing.lg)
            }

            if !selectedStyles.isEmpty && !isSearchFocused {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSSpacing.sm) {
                        ForEach(selectedStyles, id: \.self) { style in
                            styleChip(style)
                        }
                    }
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.vertical, DSSpacing.md)
                }
            }

            if isSearchFocused {
                suggestions
            } else {
                ideasContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.background)
        .overlay(alignment: .bottom) {
            if !isSearchFocused {
                DSFloatingSearchButton(title: submittedQuery.isEmpty ? "Search Styles" : submittedQuery) {
                    isSearchFocused = true
                }
                .accessibilityIdentifier("discovery.searchButton")
                .padding(.horizontal, DSSpacing.lg)
                .padding(.bottom, DSSpacing.sm)
            }
        }
        .task { search() }
        .onDisappear { model.cancel() }
        .onChange(of: selectedStyles) { _, _ in
            if !isSearchFocused { search() }
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(usesDemoStyles ? "Suggested styles" : "Search by name or category")
                .font(DSFont.search)
                .foregroundStyle(DSColor.textMuted)
                .padding(.leading, DSSpacing.xs)
                .padding(.top, DSSpacing.lg)
                .padding(.bottom, DSSpacing.sm)

            VStack(spacing: DSSpacing.sm) {
                ForEach(Array((usesDemoStyles ? styles : []).filter { !selectedStyles.contains($0) && !dismissedStyles.contains($0) }.prefix(3)), id: \.self) { style in
                    HStack(spacing: 0) {
                        Button(style) {
                            selectedStyles.append(style)
                        }
                        .font(DSFont.label)
                        .foregroundStyle(DSColor.textStrong)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .padding(.leading, DSSpacing.lg)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("discovery.style.select.\(style)")

                        Button {
                            dismissedStyles.insert(style)
                        } label: {
                            DSIcon("TablerX", size: 20)
                                .foregroundStyle(DSColor.textMuted)
                                .frame(width: 48, height: 48)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss \(style)")
                    }
                    .background(DSColor.tile, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                }
            }

            if !selectedStyles.isEmpty {
                Button(action: submitSearch) {
                    Text("Show results").frame(maxWidth: .infinity)
                }
                .buttonStyle(.ds(.primary))
                .accessibilityIdentifier("discovery.showResults")
                .padding(.top, DSSpacing.lg)
            }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { isSearchFocused = false }
                .accessibilityLabel("Back to Discovery ideas")
                .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, DSSpacing.lg)
    }

    @ViewBuilder
    private var ideasContent: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView("Loading ideas…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Ideas unavailable", tabler: "TablerWifiOff", size: 48)
            } description: {
                Text(message)
            } actions: {
                Button("Retry", action: search)
            }
        case .loaded(let products):
            let visible = products.filter(matchesStyles)
            if visible.isEmpty {
                ContentUnavailableView("No matching ideas", tabler: "TablerSearch",
                                       description: Text("Try another search or style."))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: DSSpacing.md) {
                        ForEach(visible) { product in
                            NavigationLink {
                                DiscoveryIdeaDetailView(product: product)
                            } label: {
                                DiscoveryIdeaTile(product: product)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(product.title), \(product.category.rawValue)")
                            .accessibilityIdentifier("discovery.idea.\(product.id)")
                        }
                    }
                    .padding(.horizontal, DSSpacing.lg)
                    .padding(.bottom, DSFloatingSearchButton.height + DSSpacing.sm + DSSpacing.lg)
                }
                .accessibilityIdentifier("discovery.ideaGrid")
            }
        }
    }

    private func matchesStyles(_ product: CatalogProduct) -> Bool {
        guard !selectedStyles.isEmpty else { return true }
        // The prototype's style labels are fixture-only until a public style contract exists.
        let fixtureStyles = DiscoveryCatalogSource.demoStyles[product.id] ?? []
        return selectedStyles.contains { fixtureStyles.contains($0) }
    }

    private func submitSearch() {
        submittedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        isSearchFocused = false
        search()
    }

    private func clearSearch() {
        query = ""
        submittedQuery = ""
        selectedStyles = []
        search()
    }

    private func removeStyle(_ style: String) {
        selectedStyles.removeAll { $0 == style }
    }

    private func styleChip(_ style: String) -> some View {
        DSChip(title: style, isSelected: true, icon: "TablerX") { removeStyle(style) }
            .accessibilityLabel("Remove \(style) style")
            .accessibilityIdentifier("discovery.style.remove.\(style)")
    }

    private func search() {
        model.search(query: submittedQuery, category: nil)
    }
}

/// The prototype keeps style tokens in the field while it has keyboard focus.
private struct DiscoveryIdeasSearchField: View {
    @Binding var query: String
    let selectedStyles: [String]
    @Binding var isFocused: Bool
    let onRemoveStyle: (String) -> Void
    let onSubmit: () -> Void
    let onClear: () -> Void
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            DSIcon("TablerSearch", size: 20)
                .foregroundStyle(DSColor.textMuted)

            if fieldFocused {
                ForEach(selectedStyles, id: \.self) { style in
                    DSChip(title: style, isSelected: true, icon: "TablerX") {
                        onRemoveStyle(style)
                        fieldFocused = true
                    }
                    .accessibilityLabel("Remove \(style) style")
                    .accessibilityIdentifier("discovery.style.remove.\(style)")
                }
            }

            TextField("Search", text: $query)
                .font(DSFont.label)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .tint(.primary)
                .focused($fieldFocused)
                .frame(minWidth: 72)
                .onSubmit(onSubmit)
                .accessibilityIdentifier("searchField.textField")

            if !query.isEmpty {
                Button(action: onClear) {
                    DSIcon("TablerCircleXFilled", size: 18)
                        .foregroundStyle(DSColor.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
                .accessibilityIdentifier("searchField.clearButton")
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .frame(minHeight: 56)
        .background {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .fill(DSColor.tile)
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                        .stroke(fieldFocused ? DSColor.fieldBorder : .clear, lineWidth: 1)
                )
        }
        .onAppear { fieldFocused = isFocused }
        .onChange(of: fieldFocused) { _, newValue in
            isFocused = newValue
        }
        .onChange(of: isFocused) { _, newValue in
            if fieldFocused != newValue { fieldFocused = newValue }
        }
    }
}

private struct DiscoveryIdeaTile: View {
    let product: CatalogProduct

    var body: some View {
        DSTile(style: .photo) {
            CatalogProductImage(product: product)
        }
    }
}

private struct DiscoveryIdeaDetailView: View {
    let product: CatalogProduct

    private var usableProductURL: URL? {
        guard product.productURL.scheme == "https",
              product.productURL.host?.hasSuffix(".example") != true else { return nil }
        return product.productURL
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                DSTile(style: .photo) {
                    CatalogProductImage(product: product)
                }
                Text(product.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DSColor.textPrimary)
                Text(product.category.rawValue.capitalized)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textMuted)
                Text("Source: \(product.sourceName)")
                    .font(DSFont.body)
                if let price = product.formattedPrice {
                    Text(price).font(DSFont.bodyEmphasis)
                }
                if let usableProductURL {
                    Link(destination: usableProductURL) {
                        Label("View at \(product.sourceName)", tabler: "TablerExternalLink", size: 20)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.ds(.primary))
                } else {
                    Text("Product link unavailable")
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textMuted)
                }
            }
            .padding(DSSpacing.lg)
        }
        .navigationTitle("Clothing idea")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { DiscoveryIdeasView(service: DemoCatalogService()) }
}
