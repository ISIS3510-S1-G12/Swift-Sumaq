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
    
    func getLastNewRestaurantVisit() async -> Date? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        
        do {
            let snapshot = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<QuerySnapshot, Error>) in
                db.collection(coll)
                    .whereField("userId", isEqualTo: "/Users/\(uid)")
                    .order(by: "visitedAt", descending: true)
                    .limit(to: 50) // Obtener las últimas 50 visitas para analizar
                    .getDocuments { snapshot, error in
                        if let error { cont.resume(throwing: error) }
                        else if let snapshot { cont.resume(returning: snapshot) }
                    }
            }
            
            // Obtiene todos los restaurantIds únicos que el usuario ha visitado
            var visitedRestaurants: Set<String> = []
            var lastNewRestaurantVisit: Date?
            
            for document in snapshot.documents {
                let data = document.data()
                
                guard let visitedAt = data["visitedAt"] as? Timestamp,
                      let restaurantId = data["restaurantId"] as? String else { 
                    continue 
                }
                
                let restaurantIdClean = restaurantId.replacingOccurrences(of: "/Restaurants/", with: "")
                
                // significa que fue el último restaurante "nuevo" que visitó
                if !visitedRestaurants.contains(restaurantIdClean) {
                    visitedRestaurants.insert(restaurantIdClean)
                    lastNewRestaurantVisit = visitedAt.dateValue()
                }
            }
            
            return lastNewRestaurantVisit
        } catch {
            print("Error getting last new restaurant visit: \(error)")
            return nil
        }
    }
}
