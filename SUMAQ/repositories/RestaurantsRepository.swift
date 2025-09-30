//
//  RestaurantsRepository.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

import Foundation
import FirebaseFirestore

public struct RestaurantDTO: Identifiable {
    public let id: String
    public let name: String
    public let typeOfFood: String
    public let offer: Bool
    public let rating: Double
    public let openingTime: Int?
    public let closingTime: Int?
    public let imageUrl: String?
    public let address: String?
    public let busiest: [String:String]

    init?(id: String, data: [String:Any]) {
        self.id = id
        self.name = data["name"] as? String ?? ""
        self.typeOfFood = data["typeOfFood"] as? String ?? ""
        self.offer = data["offer"] as? Bool ?? false
        self.rating = (data["rating"] as? Double) ?? 0.0
        self.openingTime = data["opening_time"] as? Int
        self.closingTime = data["closing_time"] as? Int
        self.imageUrl = data["imageUrl"] as? String
        self.address = data["address"] as? String
        self.busiest = data["busiest_hours"] as? [String:String] ?? [:]
    }
}

protocol RestaurantsRepositoryType {
    func all() async throws -> [RestaurantDTO]
}

final class RestaurantsRepository: RestaurantsRepositoryType {
    private let db = Firestore.firestore()

    func all() async throws -> [RestaurantDTO] {
        try await withCheckedThrowingContinuation { cont in
            db.collection("Restaurants").getDocuments { snap, err in
                if let err = err { cont.resume(throwing: err); return }
                let items = snap?.documents.compactMap { RestaurantDTO(id: $0.documentID, data: $0.data()) } ?? []
                cont.resume(returning: items)
            }
        }
    }
}
