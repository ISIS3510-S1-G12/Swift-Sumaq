//
//  RestaurantsRepository.swift
//  SUMAQ
//

import Foundation
import FirebaseFirestore

protocol RestaurantsRepositoryType {
    func all() async throws -> [Restaurant]
    func updateCoordinates(id: String, lat: Double, lon: Double) async throws
    func getMany(ids: [String]) async throws -> [Restaurant]
}

final class RestaurantsRepository: RestaurantsRepositoryType {
    private let db = Firestore.firestore()

    func all() async throws -> [Restaurant] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Restaurant], Error>) in
            db.collection("Restaurants").getDocuments { qs, err in
                if let err { cont.resume(throwing: err); return }
                let items = qs?.documents.compactMap { Restaurant(doc: $0) } ?? []
                cont.resume(returning: items)
            }
        }
    }

    func updateCoordinates(id: String, lat: Double, lon: Double) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.collection("Restaurants").document(id)
                .setData(["lat": lat, "lon": lon], merge: true) { err in
                    if let err { cont.resume(throwing: err) }
                    else { cont.resume(returning: ()) }
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
                        if let err { cont.resume(throwing: err) }
                        else if let qs { cont.resume(returning: qs) }
                        else { cont.resume(throwing: NSError(domain: "Firestore", code: -1)) }
                    }
            }
            result.append(contentsOf: qs.documents.compactMap { Restaurant(doc: $0) })
        }

        let order = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        return result.sorted { (order[$0.id] ?? 0) < (order[$1.id] ?? 0) }
    }
}

// MARK: - Array helper
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
