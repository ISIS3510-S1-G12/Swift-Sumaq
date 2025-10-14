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
            "userId": uid,
            "restaurantId": restaurantId,
            "visitedAt": FieldValue.serverTimestamp()
        ]

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.collection(coll).document(id).setData(payload, merge: true) { err in
                if let err { cont.resume(throwing: err) }
                else { 
                    NotificationCenter.default.post(name: .restaurantMarkedVisited, object: nil)
                    cont.resume(returning: ()) 
                }
            }
        }
    }
    
    func getAllUserVisits() async throws -> [Visit] {
        let uid = try currentUid()
        let qs = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<QuerySnapshot, Error>) in
            db.collection(coll)
                .whereField("userId", isEqualTo: uid)
                .order(by: "visitedAt", descending: true)
                .getDocuments { qs, err in
                    if let err { cont.resume(throwing: err) }
                    else if let qs { cont.resume(returning: qs) }
                    else { cont.resume(throwing: NSError(domain: "Firestore", code: -1)) }
                }
        }
        
        let visits = qs.documents.compactMap { Visit(doc: $0) }
        return visits
    }
}
