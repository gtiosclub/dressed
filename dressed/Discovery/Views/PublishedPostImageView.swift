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

//// MARK: - Local fixtures (no Firebase, no private paths)
//
//private extension UIImage {
//    /// A grey image with a white circle. If the view ever stretched the image,
//    /// the circle would turn into an oval, so it doubles as a proportion check.
//    static func fixture(width: CGFloat, height: CGFloat) -> UIImage {
//        let size = CGSize(width: width, height: height)
//        return UIGraphicsImageRenderer(size: size).image { context in
//            UIColor(white: 0.45, alpha: 1).setFill()
//            context.fill(CGRect(origin: .zero, size: size))
//            let diameter = min(width, height) * 0.5
//            UIColor.white.setFill()
//            context.cgContext.fillEllipse(in: CGRect(
//                x: (width - diameter) / 2,
//                y: (height - diameter) / 2,
//                width: diameter,
//                height: diameter
//            ))
//        }
//    }
//}

//#Preview("Supplied image") {
//    PublishedPostImageView(image: .fixture(width: 400, height: 500))
//        .padding(.horizontal, 20)
//}
//
//#Preview("Tall and wide images, narrow width") {
//    HStack(alignment: .top, spacing: 12) {
//        PublishedPostImageView(image: .fixture(width: 300, height: 600))
//        PublishedPostImageView(image: .fixture(width: 600, height: 300))
//    }
//    .frame(width: 280)
//    .padding()
//}
//
//#Preview("No image") {
//    PublishedPostImageView(image: nil)
//        .padding(.horizontal, 20)
//}
