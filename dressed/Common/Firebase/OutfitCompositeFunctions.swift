import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

enum OutfitCompositeFunctions {
    static func isOwnerSignedIn(_ ownerId: String) -> Bool {
        Auth.auth().currentUser?.uid == ownerId
    }

    static func upload(record: OutfitCompositeRecord, pngData: Data) async {
        let uid = Auth.auth().currentUser?.uid
        guard uid == record.ownerId, !pngData.isEmpty, !record.cacheKey.isEmpty else { return }
        let db = Firestore.firestore()
        let metadata: [String: Any] = [
            "id": record.cacheKey,
            "cacheKey": record.cacheKey,
            "ownerId": record.ownerId,
            "garmentIds": record.garmentIds,
            "avatarId": record.avatarId as Any,
            "avatarVersion": record.avatarVersion,
            "processingVersion": record.processingVersion,
            "storagePath": record.storagePath as Any,
            "status": record.status.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        do {
            let doc = db.collection("users").document(record.ownerId)
                .collection("outfitComposites").document(record.cacheKey)
            let existing = try await doc.getDocument(source: .server)
            if existing.exists {
                var patch = metadata
                patch.removeValue(forKey: "id")
                try await doc.updateData(patch)
            } else {
                var create = metadata
                create["createdAt"] = FieldValue.serverTimestamp()
                try await doc.setData(create)
            }
            if let path = record.storagePath {
                let ref = Storage.storage().reference(withPath: path)
                let objectMetadata = StorageMetadata()
                objectMetadata.contentType = "image/png"
                _ = try await ref.putDataAsync(pngData, metadata: objectMetadata)
            }
            let indexRef = db.collection("users").document(record.ownerId)
                .collection("outfitCacheIndex").document(OutfitCacheIndexRecord.documentId)
            try await indexRef.setData([
                "id": OutfitCacheIndexRecord.documentId,
                "schemaVersion": 1,
                "ownerId": record.ownerId,
                "cachedKeys": FieldValue.arrayUnion([record.cacheKey]),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            // Local cache remains authoritative; sync retries on the next successful render.
        }
    }

    static func downloadMetadata(ownerId: String, cacheKey: String) async throws -> OutfitCompositeRecord? {
        let snapshot = try await Firestore.firestore()
            .collection("users").document(ownerId)
            .collection("outfitComposites").document(cacheKey)
            .getDocument(source: .server)
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        let decoder = Firestore.Decoder()
        return try decoder.decode(OutfitCompositeRecord.self, from: data)
    }

    static func downloadPNG(storagePath: String, maxBytes: Int64 = 12 * 1024 * 1024) async throws -> Data {
        try await Storage.storage().reference(withPath: storagePath).data(maxSize: maxBytes)
    }
}