//
//  Visit.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDO�O on 14/10/25.
//

import Foundation
import FirebaseFirestore

struct Visit: Identifiable {
    let id: String
    let userId: String
    let restaurantId: String
    let visitedAt: Date
    
    init?(doc: DocumentSnapshot) {
        let data = doc.data() ?? [:]
        guard
            let userId = data["userId"] as? String,
            let restaurantId = data["restaurantId"] as? String,
            let visitedAtTimestamp = data["visitedAt"] as? Timestamp
        else { return nil }
        
        self.id = doc.documentID
        self.userId = userId
        self.restaurantId = restaurantId
        self.visitedAt = visitedAtTimestamp.dateValue()
    }
}
