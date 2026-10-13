//
//  ProfileView.swift
//  dressed
//
//  Created by Tiana Prem  on 9/29/26.
//

import SwiftUI

struct ProfileHeader: View {
    let avatar : Image
    let name: String
    let username: String
    
    var body: some View {
        VStack {
            HStack {
                avatar
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .padding(.leading, 10)
                VStack(alignment: .leading) {
                    Text(name)
                        .font(.system(size: 24))
                    Text(username)
                        .font(.system(size: 18))
                }
                .padding()
            }
            Spacer()
        }

        //.padding(.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

#Preview {
    ProfileHeader(avatar: Image(systemName: "person.circle.fill"),
        name: "Alexandra Elizabeth Montgomery-Williams",
        username: "@alexandra")
}
