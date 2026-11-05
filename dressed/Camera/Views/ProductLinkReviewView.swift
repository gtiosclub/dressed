import SwiftUI

struct ProductLinkReviewView: View {
    let link: ReviewProductLink
    let ownerId: String
    var importService: any ProductLinkImportService = LocalProductLinkImport()
    let onLater: () -> Void
    let onSaved: () -> Void

    @State private var name = ""
    @State private var category: ClothingCategory = .other
    @State private var confirmed = false
    @State private var errorMessage: String?
    @State private var saving = false
    @State private var loadingDetails = false
    @State private var draft: ProductImportDraft?
    @State private var importNote: String?
    @State private var keepRetailer = true
    @State private var keepImage = true
    @State private var keepPrice = true
    @State private var keepAvailability = true
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Product source") {
                    LabeledContent("Website", value: link.url.host ?? "Unknown")
                    Link(destination: link.url) {
                        Label("Open product page", systemImage: "arrow.up.right.square")
                    }
                    Text(link.url.absoluteString)
                        .font(.footnote)
                        .textSelection(.enabled)
                }

                if loadingDetails {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Reading the page…")
                        }
                    }
                }

                if let importNote {
                    Section { Text(importNote).font(.footnote).foregroundStyle(.secondary) }
                }

                pageDetailsSection

                Section("Review details") {
                    TextField("Product name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { nameFocused = false }
                        .accessibilityIdentifier("productLink.name")
                    if let source = fieldSource(draft?.fields.name, matching: name) {
                        Text(source).font(.footnote).foregroundStyle(.secondary)
                    }
                    Picker("Category", selection: $category) {
                        ForEach(ClothingCategory.allCases, id: \.self) { option in
                            Text(option.rawValue.capitalized).tag(option)
                        }
                    }
                    if draft?.fields.category.state == "suggested", let hint = draft?.fields.category.evidence {
                        Text("The page lists “\(hint)”. Pick the matching category.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Toggle("Save this link to my Wishlist", isOn: $confirmed)
                    Text("Details marked with a source came from the page. "
                        + "Anything not listed was not stated there, so check the page and edit as needed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }

                Section {
                    Button(saving ? "Saving…" : "Save to Wishlist", action: save)
                        .disabled(saving || !confirmed || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Review Product Link")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(link.isShared ? "Later" : "Cancel", action: onLater)
                }
            }
            .task(id: link.id) { await loadDetails() }
        }
    }

    // MARK: - Page details

    @ViewBuilder
    private var pageDetailsSection: some View {
        if let fields = draft?.fields, draft?.status == "ready", hasPageDetails(fields) {
            Section("Found on the page (turn off to leave out)") {
                if let retailer = pageValue(fields.retailer) {
                    Toggle(isOn: $keepRetailer) {
                        detailLabel("Store", retailer, source: sourceLabel(fields.retailer))
                    }
                }
                if let imageURL = pageImageURL(fields) {
                    Toggle(isOn: $keepImage) {
                        HStack {
                            AsyncImage(url: imageURL) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Color.secondary.opacity(0.15)
                                }
                            }
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            detailLabel("Image", nil, source: sourceLabel(fields.image))
                        }
                    }
                }
                if let price = fields.price.value, fields.price.state == "from_page" {
                    Toggle(isOn: $keepPrice) {
                        detailLabel("Price", "\(price.amount) \(price.currency)", source: sourceLabel(fields.price))
                    }
                }
                if let availability = pageValue(fields.availability) {
                    Toggle(isOn: $keepAvailability) {
                        detailLabel("Availability", availability, source: sourceLabel(fields.availability))
                    }
                }
                variantRow(fields)
            }
        }
    }

    @ViewBuilder
    private func variantRow(_ fields: ProductImportDraft.Fields) -> some View {
        if let variant = fields.variant.value, fields.variant.state == "from_link" {
            detailLabel("Variant", variant, source: "From the link")
        } else {
            Text("Color and size are not named in this link. Choose them on the store page.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func detailLabel(_ title: String, _ value: String?, source: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.map { "\(title): \($0)" } ?? title)
            Text(source).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func pageValue(_ field: ProductImportField<String>) -> String? {
        field.state == "from_page" ? field.value : nil
    }

    private func pageImageURL(_ fields: ProductImportDraft.Fields) -> URL? {
        guard fields.image.state == "from_page", let text = fields.image.value,
              let url = URL(string: text), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }

    private func hasPageDetails(_ fields: ProductImportDraft.Fields) -> Bool {
        pageValue(fields.retailer) != nil || pageImageURL(fields) != nil
            || (fields.price.value != nil && fields.price.state == "from_page")
            || pageValue(fields.availability) != nil
    }

    private func sourceLabel<Value>(_ field: ProductImportField<Value>) -> String {
        switch field.source {
        case "json-ld": "From the page (product data)"
        case "microdata": "From the page (product markup)"
        case "open-graph": "From the page (share tags)"
        case "link": "From the link"
        default: "From the page"
        }
    }

    private func fieldSource(_ field: ProductImportField<String>?, matching text: String) -> String? {
        guard let field, field.state == "from_page", field.value == text else { return nil }
        return sourceLabel(field)
    }

    // MARK: - Load and save

    private func loadDetails() async {
        loadingDetails = true
        defer { loadingDetails = false }
        do {
            let result = try await importService.draft(for: link.url, requestID: link.id)
            apply(result)
        } catch {
            importNote = error.localizedDescription
        }
    }

    private func apply(_ result: ProductImportDraft) {
        importNote = result.message
        guard result.status == "ready" else { return }
        draft = result
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let value = pageValue(result.fields.name) {
            name = value
        }
        if category == .other, result.fields.category.state == "from_page",
           let raw = result.fields.category.value, let match = ClothingCategory(rawValue: raw) {
            category = match
        }
    }

    private func confirmedDetails() -> ConfirmedProductDetails? {
        guard let draft, draft.status == "ready" else { return nil }
        let fields = draft.fields
        return ConfirmedProductDetails(
            importId: draft.importId,
            retailer: keepRetailer ? pageValue(fields.retailer) : nil,
            imageURL: keepImage ? pageImageURL(fields) : nil,
            price: keepPrice && fields.price.state == "from_page" ? fields.price.value : nil,
            availability: keepAvailability ? pageValue(fields.availability) : nil,
            variant: fields.variant.state == "from_link" ? fields.variant.value : nil
        )
    }

    private func save() {
        saving = true
        defer { saving = false }
        do {
            try ProductLinkStore(ownerId: ownerId)
                .save(link, name: name, category: category, details: confirmedDetails())
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
