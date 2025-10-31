//
//  Review.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.


import Foundation
import FirebaseFirestore
import FirebaseAuth

struct Review: Identifiable {
    let id: String
    let userId: String
    let restaurantId: String
    let stars: Int
    let comment: String
    let imageURL: String?
    let createdAt: Date?
    
    // Computed property: local image path (only for current user's reviews)
    var imageLocalPath: String? {
        guard let currentUserId = Auth.auth().currentUser?.uid,
              userId == currentUserId else {
            return nil
        }
        return ReviewImageStore.shared.getImagePath(reviewId: id)
    }

    init?(doc: DocumentSnapshot) {
        let d = doc.data() ?? [:]
        guard
            let userId = d["user_id"] as? String,
            let restaurantId = d["restaurant_id"] as? String,
            let starsAny = d["stars"]
        else { return nil }

        let starsVal: Int
        if let i = starsAny as? Int { starsVal = i }
        else if let n = starsAny as? NSNumber { starsVal = n.intValue }
        else if let d = starsAny as? Double { starsVal = Int(d) }
        else { starsVal = 0 }

        self.id           = doc.documentID
        self.userId       = userId
        self.restaurantId = restaurantId
        self.stars        = starsVal
        self.comment      = (d["comment"] as? String) ?? ""
        self.imageURL     = d["imageURL"] as? String
        if let ts = d["createdAt"] as? Timestamp { self.createdAt = ts.dateValue() }
        else { self.createdAt = nil }
    }
    
    // Initializer for creating Review from ReviewRecord (SQLite)
    init(id: String, userId: String, restaurantId: String, stars: Int, comment: String, imageURL: String?, createdAt: Date?) {
        self.id = id
        self.userId = userId
        self.restaurantId = restaurantId
        self.stars = stars
        self.comment = comment
        self.imageURL = imageURL
        self.createdAt = createdAt
    }
}
