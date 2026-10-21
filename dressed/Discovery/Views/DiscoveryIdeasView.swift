import SwiftUI

/// Individual public catalog pieces. Outfit posts live in OOTDFeedView.
struct DiscoveryIdeasView: View {
    @StateObject private var model: CatalogViewModel
    @State private var query = ""
    @State private var submittedQuery = ""
    @State private var selectedStyles: [String] = []
    @State private var dismissedStyles: Set<String> = []
    @State private var isSearchFocused = false
    let onProfile: () -> Void
    private let usesDemoStyles: Bool

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    private let styles = ["Y2K", "Colorful", "Trendy", "Comfortable", "Monotone", "Vintage", "Minimal", "Streetwear"]

    init(service: any CatalogSearching = DiscoveryCatalogSource.current, onProfile: @escaping () -> Void = {}) {
        _model = StateObject(wrappedValue: CatalogViewModel(service: service))
        self.onProfile = onProfile
        usesDemoStyles = service is DemoCatalogService
    }

    var body: some View {
        VStack(spacing: 0) {
            DiscoveryIdeasSearchField(
                query: $query,
                selectedStyles: selectedStyles,
                isFocused: $isSearchFocused,
                onRemoveStyle: removeStyle,
                onSubmit: submitSearch,
                onClear: clearSearch
            )
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, selectedStyles.isEmpty || isSearchFocused ? 0 : 12)

            if !selectedStyles.isEmpty && !isSearchFocused {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedStyles, id: \.self) { style in
                            styleChip(style)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            if isSearchFocused {
                suggestions
            } else {
                ideasContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomTrailing) {
            if !isSearchFocused {
                Button(action: onProfile) {
                    Image("TablerUserFilled")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Color(red: 0.17, green: 0.17, blue: 0.17), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profile")
                .accessibilityIdentifier("app.profileButton")
                .padding(16)
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
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
                .padding(.top, 20)
                .padding(.bottom, 8)

            VStack(spacing: 8) {
                ForEach(Array((usesDemoStyles ? styles : []).filter { !selectedStyles.contains($0) && !dismissedStyles.contains($0) }.prefix(3)), id: \.self) { style in
                    HStack(spacing: 0) {
                        Button(style) {
                            selectedStyles.append(style)
                        }
                        .font(.system(size: 17))
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .padding(.leading, 16)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("discovery.style.select.\(style)")

                        Button {
                            dismissedStyles.insert(style)
                        } label: {
                            Image("TablerX")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 20, height: 20)
                                .foregroundStyle(.secondary)
                                .frame(width: 48, height: 48)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss \(style)")
                    }
                    .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            if !selectedStyles.isEmpty {
                Button(action: submitSearch) {
                    Text("Show results")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(.black, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("discovery.showResults")
                .padding(.top, 16)
            }
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { isSearchFocused = false }
                .accessibilityLabel("Back to Discovery ideas")
                .accessibilityAddTraits(.isButton)
        }
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var ideasContent: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView("Loading ideas…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Ideas unavailable", systemImage: "wifi.exclamationmark")
            } description: {
                Text(message)
            } actions: {
                Button("Retry", action: search)
            }
        case .loaded(let products):
            let visible = products.filter(matchesStyles)
            if visible.isEmpty {
                ContentUnavailableView("No matching ideas", systemImage: "magnifyingglass",
                                       description: Text("Try another search or style."))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
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
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
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
        Button {
            removeStyle(style)
        } label: {
            HStack(spacing: 4) {
                Image("TablerX")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 14, height: 14)
                Text(style)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .frame(height: 30)
            .background(.black, in: Capsule())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
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
        HStack(spacing: 8) {
            Image("TablerSearch")
                .renderingMode(.template)
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            if fieldFocused {
                ForEach(selectedStyles, id: \.self) { style in
                    Button {
                        onRemoveStyle(style)
                        fieldFocused = true
                    } label: {
                        HStack(spacing: 4) {
                            Image("TablerX")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 14, height: 14)
                            Text(style)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.leading, 8)
                        .padding(.trailing, 12)
                        .frame(height: 30)
                        .background(.black, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(style) style")
                    .accessibilityIdentifier("discovery.style.remove.\(style)")
                }
            }

            TextField("Search", text: $query)
                .font(.system(size: 17))
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
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
                .accessibilityIdentifier("searchField.clearButton")
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Color.black.opacity(fieldFocused ? 0.12 : 0.08),
                    in: RoundedRectangle(cornerRadius: 12))
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
        CatalogProductImage(product: product)
            .aspectRatio(1, contentMode: .fit)
            .background(Color(red: 0.85, green: 0.85, blue: 0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
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
            VStack(alignment: .leading, spacing: 16) {
                CatalogProductImage(product: product)
                    .aspectRatio(1, contentMode: .fit)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(product.title).font(.title2.weight(.semibold))
                Text(product.category.rawValue.capitalized)
                    .foregroundStyle(.secondary)
                Text("Source: \(product.sourceName)")
                    .font(.subheadline)
                if let price = product.formattedPrice { Text(price) }
                if let usableProductURL {
                    Link("View at \(product.sourceName)", destination: usableProductURL)
                        .buttonStyle(.borderedProminent)
                        .tint(.black)
                } else {
                    Text("Product link unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .navigationTitle("Clothing idea")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}

#Preview {
    NavigationStack { DiscoveryIdeasView(service: DemoCatalogService()) }
}
