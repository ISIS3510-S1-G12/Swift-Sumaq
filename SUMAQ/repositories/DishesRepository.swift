//
//  DishesRepository.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

import Foundation
import FirebaseFirestore

protocol DishesRepositoryType {
    func create(forRestaurantUid uid: String,
                name: String,
                description: String,
                price: Double,
                rating: Int,
                imageUrl: String,
                dishType: String,
                dishesTags: [String]) async throws

    func listForRestaurant(uid: String) async throws -> [Dish]
}

final class DishesRepository: DishesRepositoryType {
    private let db = Firestore.firestore()
    private let collection = "Dishes"

    func create(forRestaurantUid uid: String,
                name: String,
                description: String,
                price: Double,
                rating: Int,
                imageUrl: String,
                dishType: String,
                dishesTags: [String]) async throws {

        let data: [String: Any] = [
            "name": name,
            "description": description,
            "price": price,
            "rating": rating,
            "imageUrl": imageUrl,
            "dishType": dishType,
            "dishesTags": dishesTags,
            "restaurantId": uid,
            "createdAt": FieldValue.serverTimestamp()
        ]

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.collection(collection).addDocument(data: data) { e in
                if let e { cont.resume(throwing: e) } else { cont.resume(returning: ()) }
            }
        }
    }


    func listForRestaurant(uid: String) async throws -> [Dish] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Dish], Error>) in
            db.collection(collection)
                .whereField("restaurantId", isEqualTo: uid)
                .getDocuments { qs, err in
                    if let err { cont.resume(throwing: err); return }
                    let items = (qs?.documents.compactMap { Dish(doc: $0) } ?? [])
                        .sorted {                       // ⬅️ orden local por fecha
                            ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
                        }
                    cont.resume(returning: items)
                }
        }
    }

}
