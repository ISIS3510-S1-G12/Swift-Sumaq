//
//  AppUser.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//

import Foundation
import FirebaseFirestore

struct AppUser: Identifiable {
    let id: String

    // Campos básicos (requeridos)
    let name: String
    let email: String

    // Campos opcionales
    let username: String?
    let diet: String?
    let budget: Int?
    let favoriteRestaurants: [String: Date]
    let profilePictureURL: String?
    let ownerUid: String?
    let role: String?
    let createdAt: Date?
    let updatedAt: Date?

    init?(doc: DocumentSnapshot) {
        let d = doc.data() ?? [:]

        guard
            let name = d["name"] as? String,
            let email = d["email"] as? String
        else {
            return nil
        }

        self.id = doc.documentID
        self.name = name
        self.email = email

        // --- Datos directos ---
        self.username = d["username"] as? String
        self.ownerUid = d["ownerUid"] as? String
        self.role = d["role"] as? String

        if let ts = d["created_at"] as? Timestamp {
            self.createdAt = ts.dateValue()
        } else {
            self.createdAt = nil
        }

        if let ts = d["updated_at"] as? Timestamp {
            self.updatedAt = ts.dateValue()
        } else {
            self.updatedAt = nil
        }

        // --- Favorites ---
        if let map = d["favorite_restaurants"] as? [String: Timestamp] {
            var out: [String: Date] = [:]
            map.forEach { out[$0.key] = $0.value.dateValue() }
            self.favoriteRestaurants = out
        } else {
            self.favoriteRestaurants = [:]
        }

        // --- Preferences anidadas ---
        if let preferences = d["preferences"] as? [String: Any] {
            self.budget = preferences["budget"] as? Int
            let prefDiet = preferences["diet"] as? String
            self.profilePictureURL = preferences["profile_picture"] as? String

            // Si también tienes diet a nivel raíz, preferimos la de preferences
            let rootDiet = d["diet"] as? String
            self.diet = (prefDiet?.isEmpty == false ? prefDiet : rootDiet)
        } else {
            // No hay mapa preferences → usamos solo campos sueltos
            self.budget = d["budget"] as? Int
            self.diet = d["diet"] as? String
            self.profilePictureURL = nil
        }
    }
}
