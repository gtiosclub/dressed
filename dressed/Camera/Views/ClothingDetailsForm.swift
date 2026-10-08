//
//  ClothingDetailsForm.swift
//  dressed
//
//  Created by Darsh Shetty on 10/7/26.
//

import SwiftUI

struct ClothingDetailsForm: View {
    @Binding var name: String
    @Binding var category: ClothingCategory

    let onSave: (String, ClothingCategory) -> Void

    var body: some View {
        Form {
            TextField("Name", text: $name)

            Picker("Category", selection: $category) {
                ForEach(ClothingCategory.allCases, id: \.self) { category in
                    Text(category.rawValue.capitalized)
                        .tag(category)
                }
            }

            Button("Save") {
                onSave(
                    name.trimmingCharacters(in: .whitespacesAndNewlines),
                    category
                )
            }
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
