import SwiftUI

struct ProductLinkReviewView: View {
    let link: ReviewProductLink
    let ownerId: String
    let onLater: () -> Void
    let onSaved: () -> Void

    @State private var name = ""
    @State private var category: ClothingCategory = .other
    @State private var confirmed = false
    @State private var errorMessage: String?
    @State private var saving = false
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

                Section("Review details") {
                    TextField("Product name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit { nameFocused = false }
                    Picker("Category", selection: $category) {
                        ForEach(ClothingCategory.allCases, id: \.self) { option in
                            Text(option.rawValue.capitalized).tag(option)
                        }
                    }
                    Toggle("Save this link to my Wishlist", isOn: $confirmed)
                    Text("Check the page and enter its product name. Dressed has not verified its price, availability, or image.")
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
        }
    }

    private func save() {
        saving = true
        defer { saving = false }
        do {
            try ProductLinkStore(ownerId: ownerId).save(link, name: name, category: category)
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
