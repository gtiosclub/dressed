//
//  ClothingFilter.swift
//  dressed
//
//  Created by Jiyun Kim on 10/5/26.
//
import Foundation

func filterClothingItems (
    _ items: [ClothingItem],
    category: ClothingCategory?
) -> [ClothingItem] {
    guard let category = category else {
        return items
    }
    
    return items.filter { item in
        item.category == category
    }
}

