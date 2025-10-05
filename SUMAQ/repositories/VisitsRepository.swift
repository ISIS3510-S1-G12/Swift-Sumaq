import Foundation
import FirebaseAuth
import FirebaseFirestore

final class VisitsRepository {
    private let db = Firestore.firestore()
    private let coll = "Visits"

    private func currentUid() throws -> String {
        if let uid = Auth.auth().currentUser?.uid { return uid }
        throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No session"])
    }

    private func docId(for uid: String, restaurantId: String) -> String {
        "\(uid)__\(restaurantId)"
    }

    func hasVisited(restaurantId: String) async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        let id = docId(for: uid, restaurantId: restaurantId)
        do {
            let snap = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<DocumentSnapshot, Error>) in
                db.collection(coll).document(id).getDocument { doc, err in
                    if let err { cont.resume(throwing: err) }
                    else if let doc { cont.resume(returning: doc) }
                }
            }
            return snap.exists
        } catch { return false }
    }

    func markVisited(restaurantId: String) async throws {
        let uid = try currentUid()
        let id = docId(for: uid, restaurantId: restaurantId)

        let payload: [String: Any] = [
            "userId": "/Users/\(uid)",
            "restaurantId": "/Restaurants/\(restaurantId)",
            "visitedAt": FieldValue.serverTimestamp()
        ]

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.collection(coll).document(id).setData(payload, merge: true) { err in
                if let err { cont.resume(throwing: err) }
                else { cont.resume(returning: ()) }
            }
        }
    }
}
