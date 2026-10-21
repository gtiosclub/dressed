//
//  PublishedPostImageView.swift
//  dressed
//
//  Created by vasanth aggala on 10/21/26.
//

import SwiftUI

//  Shows one already-published post image supplied by the parent,
//  or a placeholder when there is no publishable image.
//  This view never loads media or looks at storage paths.
struct PublishedPostImageView: View {
    let image: UIImage?

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(white: 0xDE / 255))
            .aspectRatio(4 / 5, contentMode: .fit)
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit() // keeps proportions; never crops the outfit
                .accessibilityLabel("Post image")
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.largeTitle)
                Text("Post image unavailable")
                    .font(.footnote)
            }
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
        }
    }
}

