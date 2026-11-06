//
//  PostFilters.swift
//  dressed
//
//  Created by Daniel  Roldan on 11/1/26.
//

import Foundation
import SwiftUI

func filterPostsByAuthor(_ posts: [Post], authorId: String) -> [Post] {
    posts.filter { $0.authorId == authorId }
}
