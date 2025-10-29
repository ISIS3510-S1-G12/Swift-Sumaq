//
//  Records.swift
//  SUMAQ
//

import Foundation

struct UserRecord: Equatable {
    var id: String
    var name: String
    var email: String
    var profilePictureURL: String?
    var createdAt: Date?
}

struct RestaurantRecord: Equatable {
    var id: String
    var name: String
    var typeOfFood: String
    var rating: Double
    var offer: Bool
    var address: String?
    var openingTime: Int?
    var closingTime: Int?
    var imageUrl: String?
    var lat: Double?
    var lon: Double?
    var updatedAt: Date?
}

struct ReviewRecord: Equatable {
    var id: String
    var userId: String
    var restaurantId: String
    var stars: Int
    var comment: String
    var imageUrl: String?
    var createdAt: Date?
}

// MARK: - Mapping between domain and records
extension UserRecord {
    init(from user: AppUser) {
        self.id = user.id
        self.name = user.name
        self.email = user.email
        self.profilePictureURL = user.profilePictureURL
        self.createdAt = nil
    }
}

extension RestaurantRecord {
    init(from r: Restaurant) {
        self.id = r.id
        self.name = r.name
        self.typeOfFood = r.typeOfFood
        self.rating = r.rating
        self.offer = r.offer
        self.address = r.address
        self.openingTime = r.opening_time
        self.closingTime = r.closing_time
        self.imageUrl = r.imageUrl
        self.lat = r.lat
        self.lon = r.lon
        self.updatedAt = nil
    }
}

extension ReviewRecord {
    init(from r: Review) {
        self.id = r.id
        self.userId = r.userId
        self.restaurantId = r.restaurantId
        self.stars = r.stars
        self.comment = r.comment
        self.imageUrl = r.imageURL
        self.createdAt = r.createdAt
    }
}


