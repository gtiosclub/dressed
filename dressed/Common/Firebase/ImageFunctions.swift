import Foundation
import FirebaseStorage

// DATA-06 (#72): upload one item photo.
// The caller supplies the signed-in user's ID as part of the private,
// owner-scoped Storage path (users/{uid}/items/{itemId}/original.jpg);
// Storage rules enforce ownership on that path. Returns the same path
// only after Firebase reports the upload succeeded.
protocol ImageFunctions {
    func uploadClothingImage(jpegData: Data, storagePath: String) async throws -> String
}

final class FirebaseStorageImageFunctions: ImageFunctions {
    func uploadClothingImage(jpegData: Data, storagePath: String) async throws -> String {
        guard !jpegData.isEmpty else {
            throw ImageUploadError.emptyData
        }

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        let reference = Storage.storage().reference(withPath: storagePath)
        _ = try await reference.putDataAsync(jpegData, metadata: metadata)
        return storagePath
    }
}

enum ImageUploadError: Error, LocalizedError {
    case emptyData

    var errorDescription: String? {
        switch self {
        case .emptyData: "Cannot upload empty image data."
        }
    }
}
