//
//  SavedPostGrid.swift
//  dressed
//
//  Created by Tiana Prem  on 10/15/26.
//


import SwiftUI


import SwiftUI

struct CatalogProductView: View {
    let product: CatalogProduct
    let onTap: (String) -> Void

    var body: some View {
        Button {
            onTap(product.id)
        } label: {
            HStack(alignment: .center, spacing: 16) {

                // Product image
                if let image = product.image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.08))

                        Image(systemName: "photo")
                            .font(.system(size: 30))
                            .foregroundStyle(.gray)
                    }
                    .frame(width: 120, height: 120)
                }

                // Product information
                VStack(alignment: .leading, spacing: 6) {
                    Text(product.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(product.retailer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(product.category.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let price = product.price {
                        Text(price.formatted(.currency(code: "USD")))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }

                    HStack(spacing: 4) {
                        Text("View at retailer")
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .padding(.top, 4)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.15), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}
struct CatalogProduct{
    var id: String
    var name: String
    var image : Image?
    var retailer : String
    var price : Decimal?
    var link : URL?
    var category : ClothingCategory
}
