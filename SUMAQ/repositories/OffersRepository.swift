//
//  OffersRepository.swift
//  SUMAQ
//

import Foundation
import FirebaseFirestore

protocol OffersRepositoryType {
    func listAll() async throws -> [Offer]
    func listForRestaurant(uid: String) async throws -> [Offer]
    func create(forRestaurantUid uid: String,
                title: String,
                description: String,
                discountPercentage: Int,
                image: String,
                tags: [String],
                validFrom: Date,
                validTo: Date) async throws
}

final class OffersRepository: OffersRepositoryType {
    private let db = Firestore.firestore()
    private let collection = "Offers"

    // MARK: - Listados

    func listAll() async throws -> [Offer] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Offer], Error>) in
            db.collection(collection)
                .getDocuments { qs, err in
                    if let err { cont.resume(throwing: err); return }
                    var items = qs?.documents.compactMap { Offer(doc: $0) } ?? []
                    // Ordenamos en cliente para evitar índices compuestos
                    items.sort { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
                    cont.resume(returning: items)
                }
        }
    }

    func listForRestaurant(uid: String) async throws -> [Offer] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[Offer], Error>) in
            db.collection(collection)
                .whereField("restaurant_id", isEqualTo: uid)
                .getDocuments { qs, err in
                    if let err { cont.resume(throwing: err); return }
                    var items = qs?.documents.compactMap { Offer(doc: $0) } ?? []
                    items.sort { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
                    cont.resume(returning: items)
                }
        }
    }

    // MARK: - Creación

    func create(forRestaurantUid uid: String,
                title: String,
                description: String,
                discountPercentage: Int,
                image: String,
                tags: [String],
                validFrom: Date,
                validTo: Date) async throws {

        let data: [String: Any] = [
            "title": title,
            "description": description,
            "discount_percentage": discountPercentage,
            "image": image,
            "tags": tags,
            "restaurant_id": uid,
            "valid_from": Timestamp(date: validFrom),
            "valid_to":   Timestamp(date: validTo),
            "createdAt":  FieldValue.serverTimestamp()
        ]

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            db.collection(collection).addDocument(data: data) { e in
                if let e { cont.resume(throwing: e) } else { cont.resume(returning: ()) }
            }
        }
    }
}
