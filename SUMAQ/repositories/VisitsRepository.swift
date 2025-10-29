// PURPOSE: Repository for managing user restaurant visits in Firestore
// ROOT CAUSE: Firestore callback could have both querySnapshot and error as nil (edge case),
//             causing continuation to never resume in getLastNewRestaurantVisit(), hanging the caller.
// MULTITHREADING CHANGE: Ensure ALL continuations always resume by explicitly handling nil cases.
//              Added defensive checks for nil snapshots and guaranteed completion paths.
// MARK: Strategy #3 — Swift Concurrency (async/await bridging callbacks)
// THREADING NOTE: Firestore callbacks run on background threads; continuations resume on caller's context.

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
                    if let err = err {
                        cont.resume(throwing: err)
                    } else if let doc = doc {
                        cont.resume(returning: doc)
                    } else {
                        // Defensive: handle nil doc and nil error
                        let error = NSError(
                            domain: "VisitsRepository",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Firestore document returned nil and no error"]
                        )
                        cont.resume(throwing: error)
                    }
                }
            }
            return snap.exists
        } catch {
            return false
        }
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
                if let err = err {
                    cont.resume(throwing: err)
                } else {
                    cont.resume(returning: ())
                }
            }
        }
    }
    
    func getLastNewRestaurantVisit() async -> Date? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        
        do {
            let snapshot = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<QuerySnapshot, Error>) in
                db.collection(coll)
                    .whereField("userId", isEqualTo: "/Users/\(uid)")
                    .order(by: "visitedAt", descending: true)
                    .limit(to: 50)
                    .getDocuments { snapshot, error in
                        if let error = error {
                            cont.resume(throwing: error)
                        } else if let snapshot = snapshot {
                            cont.resume(returning: snapshot)
                        } else {
                            // Defensive: handle nil snapshot and nil error (shouldn't happen, but prevents hang)
                            let error = NSError(
                                domain: "VisitsRepository",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Firestore query returned nil snapshot and no error"]
                            )
                            cont.resume(throwing: error)
                        }
                    }
            }
            
            var visitedRestaurants: Set<String> = []
            var lastNewRestaurantVisit: Date?
            
            for document in snapshot.documents {
                let data = document.data()
                
                guard let visitedAt = data["visitedAt"] as? Timestamp,
                      let restaurantId = data["restaurantId"] as? String else {
                    continue
                }
                
                let restaurantIdClean = restaurantId.replacingOccurrences(of: "/Restaurants/", with: "")
                
                if !visitedRestaurants.contains(restaurantIdClean) {
                    visitedRestaurants.insert(restaurantIdClean)
                    lastNewRestaurantVisit = visitedAt.dateValue()
                }
            }
            
            return lastNewRestaurantVisit
        } catch {
            print("[VisitsRepository] Error getting last new restaurant visit: \(error.localizedDescription)")
            return nil
        }
    }
}