//
//  SearchField.swift
//  dressed
//
//  Created by Sparsh Jain on 9/29/26.
//
import SwiftUI

struct SearchField: View {
    @Binding var query: String
    var placeholder: String
    var focus: Binding<Bool>?
    var onSubmit: (() -> Void)?
    var onClear: (() -> Void)?
    @FocusState private var fieldFocused: Bool

    init(
        query: Binding<String>,
        placeholder: String = "Search",
        focus: Binding<Bool>? = nil,
        onSubmit: (() -> Void)? = nil,
        onClear: (() -> Void)? = nil
    ) {
        _query = query
        self.placeholder = placeholder
        self.focus = focus
        self.onSubmit = onSubmit
        self.onClear = onClear
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(placeholder, text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .tint(.primary)
                .focused($fieldFocused)
                .onSubmit {
                    fieldFocused = false
                    onSubmit?()
                }
                .accessibilityIdentifier("searchField.textField")

            if !query.isEmpty {
                Button {
                    if let onClear {
                        onClear()
                    } else {
                        query = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
                .accessibilityIdentifier("searchField.clearButton")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .onChange(of: fieldFocused) { _, newValue in
            focus?.wrappedValue = newValue
        }
        .onChange(of: focus?.wrappedValue) { _, newValue in
            if let newValue, fieldFocused != newValue {
                fieldFocused = newValue
            }
        }
    }
}

// MARK: - Preview (no backend required)

#Preview("Empty") {
    @Previewable @State var query = ""
    VStack {
        SearchField(query: $query)
        Spacer()
    }
    .padding()
}
