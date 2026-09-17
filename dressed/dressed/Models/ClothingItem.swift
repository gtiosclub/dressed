//
//  ClothingItem.swift
//  dressed
//

import SwiftUI

enum ClothingCategory: String, CaseIterable, Identifiable {
    case tops = "Tops"
    case bottoms = "Bottoms"
    case outerwear = "Outerwear"
    case shoes = "Shoes"
    case accessories = "Accessories"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .tops: "tshirt"
        case .bottoms: "figure.stand"
        case .outerwear: "coat"
        case .shoes: "shoe"
        case .accessories: "eyeglasses"
        }
    }
}

struct ClothingItem: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var category: ClothingCategory
    var color: Color
    var lastWorn: Date?
}

struct Outfit: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var occasion: String
    var items: [ClothingItem]
}

// MARK: - Filler data

extension ClothingItem {
    static let samples: [ClothingItem] = [
        ClothingItem(name: "White Oxford Shirt", category: .tops, color: .gray, lastWorn: .now.addingTimeInterval(-86_400 * 2)),
        ClothingItem(name: "Navy Tee", category: .tops, color: .indigo, lastWorn: .now.addingTimeInterval(-86_400 * 9)),
        ClothingItem(name: "Black Levi's 501", category: .bottoms, color: .black, lastWorn: .now.addingTimeInterval(-86_400)),
        ClothingItem(name: "Khaki Chinos", category: .bottoms, color: .brown, lastWorn: nil),
        ClothingItem(name: "Denim Jacket", category: .outerwear, color: .blue, lastWorn: .now.addingTimeInterval(-86_400 * 14)),
        ClothingItem(name: "Wool Overcoat", category: .outerwear, color: .gray, lastWorn: nil),
        ClothingItem(name: "White Sneakers", category: .shoes, color: .white, lastWorn: .now.addingTimeInterval(-86_400 * 3)),
        ClothingItem(name: "Brown Loafers", category: .shoes, color: .brown, lastWorn: .now.addingTimeInterval(-86_400 * 21)),
        ClothingItem(name: "Canvas Tote", category: .accessories, color: .green, lastWorn: nil)
    ]
}

extension Outfit {
    private static func pick(_ indices: [Int]) -> [ClothingItem] {
        indices.map { ClothingItem.samples[$0] }
    }

    static let samples: [Outfit] = [
        Outfit(name: "Lecture Day", occasion: "Casual", items: pick([1, 2, 6])),
        Outfit(name: "Career Fair", occasion: "Business Casual", items: pick([0, 3, 7])),
        Outfit(name: "Cold Front", occasion: "Layered", items: pick([0, 2, 5, 6]))
    ]
}
