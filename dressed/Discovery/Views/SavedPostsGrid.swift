//
//  SavedPostsGrid.swift
//  dressed
//
//  Created by Tiana Prem  on 10/11/26.
//

import SwiftUI

struct SavedPostGrid: View {
    let posts: [SavedPost]
    let images: [String: UIImage]
    let onPostTap: (String) -> Void

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    var body: some View {
        Text("Saved Posts")
            .font(.largeTitle)
            .fontWeight(.bold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        if(posts.isEmpty){
            Spacer()
            VStack{
                Image(systemName: "person.2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80)
                    .padding(10)
                Text("No saved posts yet")
            }
            Spacer()
        } else {
            ScrollView{
                LazyVGrid(columns:columns, spacing: 10){
                    ForEach(posts){ post in
                        Button{
                            onPostTap(post.postId)
                        } label: {
                            if let image = images[post.postId] {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 180)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } else {
                                Image(systemName: "photo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 180)
                                    .frame(maxWidth: .infinity)
                                    
                                    
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
}

