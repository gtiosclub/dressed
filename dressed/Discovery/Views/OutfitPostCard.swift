//
//  OutfitPostCard.swift
//  dressed
//
//  Created by Yingqi Chen on 9/29/26.
//

import SwiftUI

struct OutfitPostCard: View {
    let outfitImage: Image
    let username: String
    let caption: String
    let isSaved: Bool
    let onSaveTap: () -> Void
    var body: some View {
        VStack {
            outfitImage
                .resizable()
                .scaledToFit()
                .cornerRadius(16)
                .accessibilityLabel("Outfit shared by \(username)")
            HStack(alignment: .top) {
                Text("\(usernameText): \(caption)")
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Caption shared by \(username) is \(caption)")

                Button {
                    onSaveTap()
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20))
                }
                .accessibilityLabel(isSaved ? "Unsave outfit" : "Save outfit")
            }

        }
        .padding()

    }

    private var usernameText: Text {
        Text(username)
            .fontWeight(.semibold)
    }

}

#Preview("Unsaved") {
    OutfitPostCard(
        outfitImage: Image("supplied_img"),
        username: "Andrea_lily",
        caption: """
        The reason i feel like i need to share this
        supplied image is
        because i really like orange color, no lie...
        """,
        isSaved: false,
        onSaveTap: {
            print("Save tapped")
        }
    )
}

#Preview("Saved") {
    OutfitPostCard(
        outfitImage: Image("supplied_img"),
        username: "example_user",
        caption: """
        The reason i feel like i need to share this
        supplied image is
        because i really like orange color, no lie...
        """,
        isSaved: true,
        onSaveTap: {
            print("Save tapped")
        }
    )
}
