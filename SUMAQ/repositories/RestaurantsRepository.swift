// PURPOSE: Repository for fetching restaurant data from Firestore
// ROOT CAUSE: Firestore callback could have both querySnapshot and error as nil (edge case),
//             causing continuation to never resume, which hangs the calling async function indefinitely.
// MULTITHREADING CHANGE: Ensure continuation ALWAYS resumes by handling all nil cases explicitly.
//              Added explicit error for nil snapshot, diagnostic logging, and guaranteed completion.
// MARK: Strategy #3 — Swift Concurrency (async/await bridging callbacks)
// THREADING NOTE: Firestore callbacks run on background threads; continuation resumes on caller's context.
//                 Main actor is not required here as this is a data layer concern.

import Foundation
import FirebaseAuth
import FirebaseFirestore

protocol RestaurantsRepositoryType {
    func all() async throws -> [Restaurant]
    func updateCoordinates(id: String, lat: Double, lon: Double) async throws
    func getMany(ids: [String]) async throws -> [Restaurant]
    func getCurrentRestaurantProfile() async throws -> AppRestaurant?
}

final class RestaurantsRepository: RestaurantsRepositoryType {
    private let db = Firestore.firestore()

    func all() async throws -> [Restaurant] {
        let startTime = Date()
        
        let result = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Restaurant], Error>) in
            db.collection("Restaurants").getDocuments { qs, err in
                if let err = err {
                    cont.resume(throwing: err)
                    return
                }
                
                // Handle case where both qs and err are nil (shouldn't happen, but defensive)
                guard let qs = qs else {
                    let error = NSError(
                        domain: "RestaurantsRepository",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Firestore returned nil query snapshot and no error"]
                    )
                    cont.resume(throwing: error)
                    return
                }
                
                let items = qs.documents.compactMap { Restaurant(doc: $0) }
                cont.resume(returning: items)
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        print("[RestaurantsRepository] Loaded \(result.count) restaurants in \(String(format: "%.2f", duration))s")
        
        return result
    }

    func updateCoordinates(id: String, lat: Double, lon: Double) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.collection("Restaurants").document(id)
                .setData(["lat": lat, "lon": lon], merge: true) { err in
                    if let err = err {
                        cont.resume(throwing: err)
                    } else {
                        cont.resume(returning: ())
                    }
                }
        }
    }

    func getMany(ids: [String]) async throws -> [Restaurant] {
        guard !ids.isEmpty else { return [] }
        var result: [Restaurant] = []
        let chunks = ids.chunked(into: 10)

        for block in chunks {
            let qs = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<QuerySnapshot, Error>) in
                db.collection("Restaurants")
                    .whereField(FieldPath.documentID(), in: block)
                    .getDocuments { qs, err in
                        if let err = err {
                            cont.resume(throwing: err)
                        } else if let qs = qs {
                            cont.resume(returning: qs)
                        } else {
                            let error = NSError(
                                domain: "RestaurantsRepository",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Firestore query returned nil snapshot and no error"]
                            )
                            cont.resume(throwing: error)
                        }
                    }
            }
            result.append(contentsOf: qs.documents.compactMap { Restaurant(doc: $0) })
        }

        let order = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        return result.sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
    }

    func getCurrentRestaurantProfile() async throws -> AppRestaurant? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        let snap = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<DocumentSnapshot, Error>) in
            db.collection("Restaurants").document(uid).getDocument { doc, err in
                if let err = err {
                    cont.resume(throwing: err)
                } else if let doc = doc {
                    cont.resume(returning: doc)
                } else {
                    let error = NSError(
                        domain: "RestaurantsRepository",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Firestore document returned nil and no error"]
                    )
                    cont.resume(throwing: error)
                }
            }
        }
        return AppRestaurant(doc: snap)
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