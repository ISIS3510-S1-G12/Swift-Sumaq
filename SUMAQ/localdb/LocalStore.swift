//
//  LocalStore.swift
//  SUMAQ
//

import Foundation

final class LocalStore {
    static let shared = LocalStore()

    let users: UsersDAO
    let restaurants: RestaurantsDAO
    let reviews: ReviewsDAO

    private init() {
        self.users = UsersDAO()
        self.restaurants = RestaurantsDAO()
        self.reviews = ReviewsDAO()
    }

    func configureIfNeeded() {
        do { try LocalDatabase.shared.configure() } catch { print("Local DB configure error: \(error)") }
    }
}


