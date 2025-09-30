//
//  OffersRepository.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

protocol OffersRepositoryType {
    func create(forRestaurantUid: String,
                title: String,
                description: String,
                discountPercentage: Int,
                image: String,
                tags: [String],
                validFrom: Date?,
                validTo: Date?) async throws

    func listForRestaurant(uid: String) async throws -> [Offer]
    func listAll() async throws -> [Offer]
}

final class OffersRepository: OffersRepositoryType {
    private let db = Firestore.firestore()
    private let collection = "Offers"

    func create(forRestaurantUid uid: String,
                title: String,
                description: String,
                discountPercentage: Int,
                image: String,
                tags: [String],
                validFrom: Date?,
                validTo: Date?) async throws {

        let offer = Offer(
            id: UUID().uuidString, //aquí no se usa como docID 
            title: title,
            description: description,
            discountPercentage: discountPercentage,
            image: image,
            restaurantPath: "/Restaurants/\(uid)",
            tags: tags,
            validFrom: validFrom,
            validTo: validTo,
            createdAt: Date()
        )

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.collection(collection).addDocument(data: offer.asFirestore) { e in
                if let e { cont.resume(throwing: e) } else { cont.resume(returning: ()) }
            }
        }
    }

    // repositories/OffersRepository.swift
    func listForRestaurant(uid: String) async throws -> [Offer] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Offer], Error>) in
            db.collection(collection)
                .whereField("restaurant_id", isEqualTo: "/Restaurants/\(uid)")
                .getDocuments { qs, err in
                    if let err { cont.resume(throwing: err); return }
                    let items = (qs?.documents.compactMap { Offer(doc: $0) } ?? [])
                        .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) } // orden local
                    cont.resume(returning: items)
                }
        }
    }


    func listAll() async throws -> [Offer] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Offer], Error>) in
            db.collection(collection)
                .order(by: "createdAt", descending: true)
                .getDocuments { qs, err in
                    if let err { cont.resume(throwing: err); return }
                    let items = qs?.documents.compactMap { Offer(doc: $0) } ?? []
                    cont.resume(returning: items)
                }
        }
    }
}

