import Foundation

// Compile with Common/Models/*.swift. This file is outside the iOS app target.
@main
struct ValidateSchemas {
    static func main() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let data = try Data(contentsOf: url)
        let fixtures = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        func check<T: Codable>(_ type: T.Type, _ key: String) throws {
            let original = fixtures[key] as! [String: Any]
            let encoded = try JSONSerialization.data(withJSONObject: original)
            let value = try decoder.decode(type, from: encoded)
            let roundTrip = try JSONSerialization.jsonObject(with: encoder.encode(value)) as! [String: Any]
            guard NSDictionary(dictionary: original).isEqual(to: roundTrip) else {
                throw NSError(domain: "SchemaFixture", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Round-trip changed \(key)"])
            }
        }

        try check(ClothingItem.self, "ClothingItem")
        try check(UserProfile.self, "UserProfile")
        try check(Outfit.self, "Outfit")
        try check(Post.self, "Post")
        try check(SavedPost.self, "SavedPost")
        try check(Follow.self, "Follow")
        try check(Avatar.self, "Avatar")
        try check(ImportDraft.self, "ImportDraft")
        try check(PreferenceEvent.self, "PreferenceEvent")
        try check(UserPreferences.self, "UserPreferences")
        try check(OutfitRecommendation.self, "OutfitRecommendation")
        try check(SimilarItemResult.self, "SimilarItemResult")
        try check(AppNotification.self, "AppNotification")
        try check(Challenge.self, "Challenge")
        try check(ChallengeSubmission.self, "ChallengeSubmission")

        var invalidItem = fixtures["ClothingItem"] as! [String: Any]
        invalidItem["category"] = "unknown-category"
        let invalidData = try JSONSerialization.data(withJSONObject: invalidItem)
        guard (try? decoder.decode(ClothingItem.self, from: invalidData)) == nil else {
            fatalError("Unknown category unexpectedly decoded")
        }
        invalidItem = fixtures["ClothingItem"] as! [String: Any]
        invalidItem.removeValue(forKey: "ownerId")
        let missingOwner = try JSONSerialization.data(withJSONObject: invalidItem)
        guard (try? decoder.decode(ClothingItem.self, from: missingOwner)) == nil else {
            fatalError("Item without owner unexpectedly decoded")
        }
        print("15 fixture round-trips and 2 invalid-input checks passed.")
    }
}
