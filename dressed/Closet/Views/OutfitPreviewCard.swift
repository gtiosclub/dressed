//
//  OutfitPreviewCard.swift
//  dressed
//
//  Created by Aditi on 10/7/26.
//
import SwiftUI

struct OutfitPreviewCard: View {
    let name: String
    private let thumbnail: AnyView
    let onTap: () -> Void

    init(name: String, image: Image, onTap: @escaping () -> Void) {
        self.name = name
        self.thumbnail = AnyView(image.resizable().scaledToFit())
        self.onTap = onTap
    }

    init(name: String, thumbnail: AnyView, onTap: @escaping () -> Void) {
        self.name = name
        self.thumbnail = thumbnail
        self.onTap = onTap
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack {
                thumbnail
                    .frame(width: 200, height: 300)
                    .clipped()
                    .accessibilityHidden(true)
                Text(name)
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(2)
            }
        }
    }
}

#Preview {
    OutfitPreviewCard(
        name: "Monday",
        image: Image(systemName: "photo"),
        onTap: {
             print("tapped") }
    )
}
