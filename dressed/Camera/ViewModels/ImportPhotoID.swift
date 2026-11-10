import CryptoKit
import Foundation

// A stable ID for a selected photo, derived from its bytes. PhotosPicker only
// reports itemIdentifier when given a photo library, so a random fallback ID
// made each re-selection look like a new import and re-saving created a second
// closet item. The same photo now always maps to the same import and item IDs.
enum ImportPhotoID {
    nonisolated static func make(for imageData: Data) -> String {
        SHA256.hash(data: imageData).prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}
