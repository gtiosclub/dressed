//
//  ProfileView.swift
//  dressed
//

import FirebaseAuth
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 56, height: 56)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(session.displayName)
                                .font(.headline)
                            Text(session.user?.email ?? "Not signed in")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Closet") {
                    LabeledContent("Items", value: "\(ClothingItem.samples.count)")
                    LabeledContent("Outfits", value: "\(Outfit.samples.count)")
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        session.signOut()
                    }
                }
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(SessionStore())
}
