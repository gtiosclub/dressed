//
//  OutfitPreviewCard.swift
//  dressed
//
//  Created by Aditi on 10/7/26.
//
import SwiftUI

struct OutfitPreviewCard: View {
    let name: String
    let image: Image
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack {
                image
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(3/4, contentMode: .fill)
                    .frame(width: 200, height: 300)
                    .clipped()
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
