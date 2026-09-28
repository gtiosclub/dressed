import Foundation

// Starter contract for DATA-04 (#70) and DATA-05 (#71).
// Students add an implementation here when their ticket is assigned.
// The caller supplies the signed-in user's ID; Firestore rules enforce ownership.
protocol ClothingFunctions {
    /// Save the supplied record at users/{ownerId}/items/{id}; throw on failure.
    func saveClothingItem(_ item: ClothingItem) async throws

    /// Read and decode users/{ownerId}/items; throw on read or decoding failure.
    func fetchClothingItems(ownerId: String) async throws -> [ClothingItem]
}
