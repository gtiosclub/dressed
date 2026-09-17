//
//  HomeView.swift
//  dressed
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }

            WardrobeView()
                .tabItem { Label("Wardrobe", systemImage: "square.grid.2x2") }

            OutfitsView()
                .tabItem { Label("Outfits", systemImage: "hanger") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(SessionStore())
}
