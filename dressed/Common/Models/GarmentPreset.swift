import Foundation
import SwiftUI

/// Preset clothing types that fit the 3D avatar mannequin.
enum GarmentPreset: String, CaseIterable, Identifiable, Codable {
    // Tops
    case tShirt = "T-Shirt"
    case hoodie = "Hoodie"
    case sweater = "Sweater"
    case sweatshirt = "Sweatshirt"
    case jersey = "Jersey"
    case tankTop = "Tank Top"
    case blouse = "Blouse"
    case cropTop = "Crop Top"
    case bikini = "Bikini"

    // Bottoms
    case jeans = "Jeans"
    case pants = "Pants"
    case shorts = "Shorts"
    case capris = "Capris"
    case leggings = "Leggings"

    // One-piece & Skirts
    case skirt = "Skirt"
    case dress = "Dress"
    case longDress = "Long Dress"

    // Accessories & Shoes
    case beanie = "Beanie"
    case sneakers = "Sneakers"
    case boots = "Boots"

    var id: String { rawValue }

    var category: ClothingCategory {
        switch self {
        case .tShirt, .hoodie, .sweater, .sweatshirt, .jersey, .tankTop, .blouse, .cropTop, .bikini:
            return .tops
        case .jeans, .pants, .shorts, .capris, .leggings:
            return .pants
        case .skirt:
            return .skirts
        case .dress, .longDress:
            return .dresses
        case .beanie:
            return .accessories
        case .sneakers, .boots:
            return .shoes
        }
    }

    var icon: String {
        switch self {
        case .tShirt: return "tshirt"
        case .hoodie: return "cloud"
        case .sweater, .sweatshirt: return "waveform"
        case .jersey: return "sportscourt"
        case .tankTop: return "figure.arms.open"
        case .blouse: return "sparkles"
        case .cropTop: return "scissors"
        case .bikini: return "water.waves"
        case .jeans, .pants: return "figure.walk"
        case .shorts: return "sun.max"
        case .capris: return "arrow.down.forward.and.arrow.up.backward"
        case .leggings: return "figure.run"
        case .skirt: return "triangle"
        case .dress, .longDress: return "figure.stand.dress"
        case .beanie: return "circle"
        case .sneakers, .boots: return "shoe"
        }
    }

    /// Whether this garment preset covers the avatar's shoulders.
    var coversShoulders: Bool {
        switch self {
        case .tShirt, .hoodie, .sweater, .sweatshirt, .jersey, .blouse, .cropTop, .dress, .longDress:
            return true
        case .tankTop, .bikini:
            return false
        default:
            return false
        }
    }

    /// Descriptive summary of how the preset fits the avatar.
    var coverageDescription: String {
        switch self {
        case .tankTop:
            return "Exposed shoulders & sleeveless tank straps"
        case .bikini:
            return "Exposed shoulders & minimal halter cut"
        case .tShirt:
            return "Shoulders covered & classic short sleeves"
        case .jersey:
            return "Shoulders covered & athletic short sleeves"
        case .cropTop:
            return "Shoulders covered & cropped midriff"
        case .blouse:
            return "Shoulders covered & flowy sleeve drape"
        case .hoodie:
            return "Full shoulder coverage, long sleeves & hood"
        case .sweater:
            return "Full shoulder coverage & knitted long sleeves"
        case .sweatshirt:
            return "Full shoulder coverage & crewneck long sleeves"
        case .dress:
            return "Shoulders covered & knee-length flare"
        case .longDress:
            return "Shoulders covered & floor-length maxi drape"
        case .jeans:
            return "Full-length 360° denim fit"
        case .pants:
            return "Full-length 360° tailored fit"
        case .leggings:
            return "Form-fitting full-length silhouette"
        case .shorts:
            return "Above-the-knee 360° cut"
        case .capris:
            return "Mid-calf 360° cropped cut"
        case .skirt:
            return "A-line flared skirt silhouette"
        case .beanie:
            return "Ribbed knit cap covering head"
        case .sneakers:
            return "Low-top athletic footwear"
        case .boots:
            return "High-top structured boot silhouette"
        }
    }

    var filterCategory: PresetFilterCategory {
        switch self {
        case .tShirt, .hoodie, .sweater, .sweatshirt, .jersey, .tankTop, .blouse, .cropTop, .bikini:
            return .tops
        case .jeans, .pants, .shorts, .capris, .leggings:
            return .bottoms
        case .skirt, .dress, .longDress:
            return .dresses
        case .beanie, .sneakers, .boots:
            return .accessories
        }
    }

    /// Automatically infers the most likely preset from text keywords, category, and stored preference.
    static func detect(name: String, category: ClothingCategory, itemId: String? = nil) -> GarmentPreset {
        if let itemId, let stored = GarmentPresetStore.get(for: itemId) {
            return stored
        }

        let lower = name.lowercased()

        if lower.contains("hoodie") { return .hoodie }
        if lower.contains("sweater") || lower.contains("pullover") { return .sweater }
        if lower.contains("sweatshirt") { return .sweatshirt }
        if lower.contains("jersey") { return .jersey }
        if lower.contains("tank") || lower.contains("sleeveless") { return .tankTop }
        if lower.contains("crop") { return .cropTop }
        if lower.contains("bikini") || lower.contains("swim") { return .bikini }
        if lower.contains("blouse") { return .blouse }
        if lower.contains("jean") || lower.contains("denim") { return .jeans }
        if lower.contains("short") { return .shorts }
        if lower.contains("capri") { return .capris }
        if lower.contains("legging") { return .leggings }
        if lower.contains("maxi") || (lower.contains("long") && lower.contains("dress")) { return .longDress }
        if lower.contains("dress") || lower.contains("gown") { return .dress }
        if lower.contains("skirt") { return .skirt }
        if lower.contains("beanie") || lower.contains("hat") || lower.contains("cap") { return .beanie }
        if lower.contains("boot") { return .boots }
        if lower.contains("shoe") || lower.contains("sneaker") { return .sneakers }

        switch category {
        case .tops: return .tShirt
        case .pants: return .jeans
        case .skirts: return .skirt
        case .dresses: return .dress
        case .outerwear: return .hoodie
        case .shoes: return .sneakers
        case .accessories: return .beanie
        case .other: return .tShirt
        }
    }
}

/// Filter categories for browsing presets in UI.
enum PresetFilterCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case tops = "Tops"
    case bottoms = "Bottoms"
    case dresses = "Dresses"
    case accessories = "Shoes & Hats"

    var id: String { rawValue }
}

/// Stores and retrieves user-chosen presets by item ID.
enum GarmentPresetStore {
    private static let keyPrefix = "garment_preset_"

    static func set(_ preset: GarmentPreset, for itemId: String) {
        UserDefaults.standard.set(preset.rawValue, forKey: keyPrefix + itemId)
    }

    static func get(for itemId: String) -> GarmentPreset? {
        guard let raw = UserDefaults.standard.string(forKey: keyPrefix + itemId) else { return nil }
        return GarmentPreset(rawValue: raw)
    }

    static func remove(for itemId: String) {
        UserDefaults.standard.removeObject(forKey: keyPrefix + itemId)
    }
}
