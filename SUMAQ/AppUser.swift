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
    let name: String
    let email: String
    let favoriteRestaurants: [String: Date]
    let profilePicture: String

    init?(doc: DocumentSnapshot) {
        let d = doc.data() ?? [:]
        guard
            let name = d["name"] as? String,
            let email = d["email"] as? String
        else { return nil }

        self.id = doc.documentID
        self.name = name
        self.email = email

        if let map = d["favorite_restaurants"] as? [String: Timestamp] {
            var out: [String: Date] = [:]
            map.forEach { out[$0.key] = $0.value.dateValue() }
            self.favoriteRestaurants = out
        } else {
            self.favoriteRestaurants = [:]
        }
        
        // Extraer profile_picture de las preferencias
        if let prefs = d["preferences"] as? [String: Any],
           let profilePic = prefs["profile_picture"] as? String {
            self.profilePicture = profilePic
        } else {
            self.profilePicture = ""
        }
    }
}
