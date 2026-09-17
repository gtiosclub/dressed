//
//  OutfitsView.swift
//  dressed
//

import SwiftUI

struct OutfitsView: View {
    private let outfits = Outfit.samples

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(outfits) { outfit in
                        NavigationLink {
                            OutfitDetailView(outfit: outfit)
                        } label: {
                            OutfitCard(outfit: outfit)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Outfits")
            .toolbar {
                Button {
                    // TODO: hook up the outfit builder
                } label: {
                    Label("New Outfit", systemImage: "plus")
                }
            }
        }
    }
}

#Preview {
    OutfitsView()
}
