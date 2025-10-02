//
//  UsersRepository.swift
//  SUMAQ
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class UsersRepository {
    private let db = Firestore.firestore()
    private let coll = "Users"
    private let favField = "favorite_restaurants"

    // MARK: - Helpers
    private func currentUid() -> String? { Auth.auth().currentUser?.uid }

    // MARK: - Favorites

    func addFavorite(restaurantId: String) async throws {
        guard let uid = currentUid() else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No session"])
        }
        let path = "\(favField).\(restaurantId)"
        let data: [String: Any] = [path: FieldValue.serverTimestamp()]

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.collection(coll).document(uid).setData(data, merge: true) { err in
                if let err { cont.resume(throwing: err) } else { cont.resume(returning: ()) }
            }
        }
    }

    func removeFavorite(restaurantId: String) async throws {
        guard let uid = currentUid() else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No session"])
        }
        let path = "\(favField).\(restaurantId)"
        let data: [String: Any] = [path: FieldValue.delete()]

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.collection(coll).document(uid).updateData(data) { err in
                if let err { cont.resume(throwing: err) } else { cont.resume(returning: ()) }
            }
        }
    }

    func isFavorite(restaurantId: String) async throws -> Bool {
        guard let uid = currentUid() else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No session"])
        }
        let snap = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<DocumentSnapshot, Error>) in
            db.collection(coll).document(uid).getDocument { doc, err in
                if let err { cont.resume(throwing: err) }
                else if let doc { cont.resume(returning: doc) }
                else { cont.resume(throwing: NSError(domain: "Firestore", code: -1)) }
            }
        }

        let data = snap.data() ?? [:]
        if let map = data[favField] as? [String: Any] {
            return map.keys.contains(restaurantId)
        }
        return false
    }

    /// Lista de IDs de restaurantes favoritos, ordenada por `serverTimestamp` descendente
    func listFavoriteRestaurantIds() async throws -> [String] {
        guard let uid = currentUid() else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No session"])
        }
        let snap = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<DocumentSnapshot, Error>) in
            db.collection(coll).document(uid).getDocument { doc, err in
                if let err { cont.resume(throwing: err) }
                else if let doc { cont.resume(returning: doc) }
                else { cont.resume(throwing: NSError(domain: "Firestore", code: -1)) }
            }
        }

        let data = snap.data() ?? [:]
        guard let rawMap = data[favField] as? [String: Any], !rawMap.isEmpty else { return [] }

        let pairs: [(String, Date)] = rawMap.compactMap { (key, val) in
            if let ts = val as? Timestamp { return (key, ts.dateValue()) }
            if let d  = val as? Date      { return (key, d) }
            return (key, Date.distantPast)
        }

        return pairs.sorted { $0.1 > $1.1 }.map { $0.0 }
    }
}
