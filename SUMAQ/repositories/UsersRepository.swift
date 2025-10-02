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

    private func currentUid() -> String? { Auth.auth().currentUser?.uid }

    // MARK: - Favorites

    func addFavorite(restaurantId: String) async throws {
        guard let uid = currentUid() else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No session"])
        }
        // mapa: favorite_restaurants.<id> = serverTimestamp
        let path = "\(favField).\(restaurantId)"
        let data: [String: Any] = [path: FieldValue.serverTimestamp()]

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.collection(coll).document(uid).setData(data, merge: true) { err in
                if let err { cont.resume(throwing: err) } else {
                    NotificationCenter.default.post(name: .userFavoritesDidChange, object: nil)
                    cont.resume(returning: ())
                }
            }
        }
    }

    func removeFavorite(restaurantId: String) async throws {
        guard let uid = currentUid() else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No session"])
        }

        // 1) Intento estándar (campo anidado): favorite_restaurants.<id> = delete
        let nestedPathKey = "\(favField).\(restaurantId)"
        let nestedDelete: [String: Any] = [nestedPathKey: FieldValue.delete()]

        // 2) Intento para el **formato aplanado** firebase db:
        //    clave literal "favorite_restaurants.<id>" (un solo segmento) -> FieldPath con array de 1 elemento
        let flatFieldPath = FieldPath([nestedPathKey])
        let flatDelete: [AnyHashable: Any] = [flatFieldPath: FieldValue.delete()]

        // si el primero no borra, el segundo lo hará.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let ref = db.collection(coll).document(uid)

            ref.updateData(nestedDelete) { _ in
                // independientemente del resultado, borrar el plano
                ref.updateData(flatDelete) { err in
                    if let err { cont.resume(throwing: err) } else {
                        NotificationCenter.default.post(name: .userFavoritesDidChange, object: nil)
                        cont.resume(returning: ())
                    }
                }
            }
        }
    }

    /// nuevo estado (true si quedó favorito).
    @discardableResult
    func toggleFavorite(restaurantId: String) async throws -> Bool {
        if try await isFavorite(restaurantId: restaurantId) {
            try await removeFavorite(restaurantId: restaurantId)
            return false
        } else {
            try await addFavorite(restaurantId: restaurantId)
            return true
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

        let map = Self.parseFavoritesMap(from: snap.data() ?? [:], favField: favField)
        return map.keys.contains(restaurantId)
    }

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

        let map = Self.parseFavoritesMap(from: snap.data() ?? [:], favField: favField)
        guard !map.isEmpty else { return [] }

        return map.sorted { $0.value > $1.value }.map { $0.key }
    }
}

// MARK: - para `favorite_restaurants`
private extension UsersRepository {

    static func parseFavoritesMap(from data: [String: Any], favField: String) -> [String: Date] {
        // Caso 1: mapa anidado normal
        if let map = data[favField] as? [String: Any] {
            var out: [String: Date] = [:]
            for (k, v) in map {
                if let ts = v as? Timestamp { out[k] = ts.dateValue() }
                else if let d = v as? Date { out[k] = d }
            }
            if !out.isEmpty { return out }
        }
        // Caso 2: aplanado "favorite_restaurants.<id>"
        var flat: [String: Date] = [:]
        for (k, v) in data where k.hasPrefix(favField + ".") {
            let id = String(k.dropFirst(favField.count + 1))
            if let ts = v as? Timestamp { flat[id] = ts.dateValue() }
            else if let d = v as? Date { flat[id] = d }
        }
        return flat
    }
}
//  Perfil actual
extension UsersRepository {
    func getCurrentUser() async throws -> AppUser? {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No session"])
        }
        let snap = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<DocumentSnapshot, Error>) in
            db.collection(coll).document(uid).getDocument { doc, err in
                if let err { cont.resume(throwing: err) }
                else if let doc { cont.resume(returning: doc) }
                else { cont.resume(throwing: NSError(domain: "Firestore", code: -1)) }
            }
        }
        return AppUser(doc: snap)
    }
}
