//
//  ProfileView.swift
//  dressed
//
//  Created by Tiana Prem  on 9/29/26.
//

import SwiftUI

struct ProfileView: View {
    
    var body: some View {
        VStack {
            HStack {
                Image("profile_icon1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .padding(.leading, 10)
                VStack(alignment: .leading) {
                    Text("Example Person")
                        .font(.system(size: 24))
                    Text("example_user")
                        .font(.system(size: 18))
                }
                .padding(10)
            }
            Spacer()
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
    }
}

#Preview {
    ProfileView()
}
