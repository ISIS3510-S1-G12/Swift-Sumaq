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
    private let local = LocalStore.shared


    private func currentUid() -> String? { Auth.auth().currentUser?.uid }


    func addFavorite(restaurantId: String) async throws {
        guard let uid = currentUid() else {
            throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No session"])
        }
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

        let nestedPathKey = "\(favField).\(restaurantId)"
        let nestedDelete: [String: Any] = [nestedPathKey: FieldValue.delete()]


        let flatFieldPath = FieldPath([nestedPathKey])
        let flatDelete: [AnyHashable: Any] = [flatFieldPath: FieldValue.delete()]

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let ref = db.collection(coll).document(uid)

            ref.updateData(nestedDelete) { _ in
                ref.updateData(flatDelete) { err in
                    if let err { cont.resume(throwing: err) } else {
                        NotificationCenter.default.post(name: .userFavoritesDidChange, object: nil)
                        cont.resume(returning: ())
                    }
                }
            }
        }
    }

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

            let sortedIds: [String] = await withCheckedContinuation { cont in
                DispatchQueue.global(qos: .userInitiated).async { [favField = self.favField] in
                    let data = snap.data() ?? [:]
                    let map  = UsersRepository.parseFavoritesMap(from: data, favField: favField)

                    guard !map.isEmpty else {
                        cont.resume(returning: [])
                        return
                    }

                    let ids = map.sorted { $0.value > $1.value }.map { $0.key }
                    cont.resume(returning: ids)
                }
            }

            try Task.checkCancellation()
            return sortedIds
        }

    
    // SPRINT 3 – Multithreading – Grand Central Dispatch (GCD)
    // Patrón usado: Uso de DispatchQueue.global(qos: .userInitiated) para ejecutar en segundo plano el trabajo de parseo y ordenamiento de los favoritos, evitando bloquear el thread principal.
    // Multithreading real: Mientras la consulta a Firestore (I/O) ocurre de forma asíncrona mediante async/await, el procesamiento de datos (conversión y ordenamiento) se delega a un hilo del pool de GCD. De esta manera, el cálculo se realiza en paralelo, liberando el main thread para mantener la interfaz fluida.
    // Cancelación: Antes de devolver el resultado final, se llama a Task.checkCancellation() para detener el proceso si la tarea fue cancelada (por ejemplo, si cambió la sesión o el usuario cerró la vista). Esto evita actualizaciones inconsistentes o estados antiguos.
    // Dónde sucede: Dentro de listFavoriteRestaurantIds(), tras obtener el DocumentSnapshot, se crea una continuación con withCheckedContinuation y se lanza un bloque en DispatchQueue.global. Allí se parsean y ordenan los datos, y luego se devuelve el resultado al flujo asíncrono mediante cont.resume(returning:).
    // Beneficio: Permite combinar async/await (para operaciones I/O) con GCD (para trabajo CPU-bound), demostrando el uso de múltiples hilos reales y optimizando el rendimiento general de la carga de favoritos.


}

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
        var flat: [String: Date] = [:]
        for (k, v) in data where k.hasPrefix(favField + ".") {
            let id = String(k.dropFirst(favField.count + 1))
            if let ts = v as? Timestamp { flat[id] = ts.dateValue() }
            else if let d = v as? Date { flat[id] = d }
        }
        return flat
    }
}
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
    
    func getManyBasic(ids: [String]) async throws -> [AppUser] {
           guard !ids.isEmpty else { return [] }
           let db = Firestore.firestore()
           var result: [AppUser] = []

           let chunks = ids.chunked(into: 10)
           for block in chunks {
               let qs = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<QuerySnapshot, Error>) in
                   db.collection("Users")
                       .whereField(FieldPath.documentID(), in: block)
                       .getDocuments { qs, err in
                           if let err { cont.resume(throwing: err) }
                           else if let qs { cont.resume(returning: qs) }
                           else { cont.resume(throwing: NSError(domain: "Firestore", code: -1)) }
                       }
               }
               result.append(contentsOf: qs.documents.compactMap { AppUser(doc: $0) })
           }
           return result
       }
   }

   private extension Array {
       func chunked(into size: Int) -> [[Element]] {
           guard size > 0 else { return [self] }
           var res: [[Element]] = []
           var i = 0
           while i < count {
               let end = Swift.min(i + size, count)
               res.append(Array(self[i..<end]))
               i = end
           }
           return res
       }
   
}
