import Foundation
import FirebaseFirestore

protocol RestaurantsRepositoryType {
    func all() async throws -> [Restaurant]
    func updateCoordinates(id: String, lat: Double, lon: Double) async throws
}

final class RestaurantsRepository: RestaurantsRepositoryType {
    private let db = Firestore.firestore()

    func all() async throws -> [Restaurant] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Restaurant], Error>) in
            db.collection("Restaurants").getDocuments { qs, err in
                if let err {
                    cont.resume(throwing: err)
                    return
                }
                let items: [Restaurant] = qs?.documents.compactMap { Restaurant(doc: $0) } ?? []
                cont.resume(returning: items)
            }
        }
    }

    func updateCoordinates(id: String, lat: Double, lon: Double) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.collection("Restaurants").document(id)
                .setData(["lat": lat, "lon": lon], merge: true) { err in
                    if let err {
                        cont.resume(throwing: err)
                    } else {
                        cont.resume(returning: ())
                    }
                }
        }
    }
}
