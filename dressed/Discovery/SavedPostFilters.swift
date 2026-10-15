import Foundation
//
//  SavedPostFilters.swift
//  dressed
//
//  Created by vasanth aggala on 10/15/26.

// takes in an array of Post values and Set<String> of saved post IDs
// returns posts in savedPostIds in the order they were supplied.
// deleted posts are saved posts w/ no id, and are thus ignored.
func filterSavedPosts(_ posts: [Post], savedPostIds: Set<String>) -> [Post] {
    posts.filter { savedPostIds.contains($0.id) }
}

