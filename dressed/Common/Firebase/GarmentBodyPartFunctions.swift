import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Foundation

/// Mirrors `GarmentBodyPartRecord` metadata and PNG bytes to Firebase when the signed-in user owns the record.
enum GarmentBodyPartFunctions {
    static func upload(record: GarmentBodyPartRecord, pngData: Data) async {
        let uid = Auth.auth().currentUser?.uid
        guard uid == record.ownerId, !pngData.isEmpty else { return }
        let db = Firestore.firestore()
        let metadata: [String: Any] = [
            "id": record.itemId,
            "ownerId": record.ownerId,
            "itemId": record.itemId,
            "slot": record.slot.rawValue,
            "category": record.category.rawValue,
            "storagePath": record.storagePath as Any,
            "generationVersion": record.generationVersion,
            "promptVersion": record.promptVersion,
            "providerVersion": record.providerVersion,
            "avatarId": record.avatarId as Any,
            "avatarVersion": record.avatarVersion as Any,
            "status": record.status.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        do {
            let doc = db.collection("users").document(record.ownerId)
                .collection("garmentBodyParts").document(record.itemId)
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
        } catch {
            // Local cache remains authoritative; sync retries on the next save or backfill.
        }
    }

    static func downloadMetadata(ownerId: String, itemId: String) async throws -> GarmentBodyPartRecord? {
        let snapshot = try await Firestore.firestore()
            .collection("users").document(ownerId)
            .collection("garmentBodyParts").document(itemId)
            .getDocument(source: .server)
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        let decoder = Firestore.Decoder()
        return try decoder.decode(GarmentBodyPartRecord.self, from: data)
    }

    static func downloadPNG(storagePath: String, maxBytes: Int64 = 12 * 1024 * 1024) async throws -> Data {
        try await Storage.storage().reference(withPath: storagePath).data(maxSize: maxBytes)
    }
}