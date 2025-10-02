//
//  Offer.swift
//  SUMAQ
//

import Foundation
import FirebaseFirestore

struct Offer: Identifiable {
    let id: String
    let title: String
    let description: String
    let image: String
    let tags: [String]
    let discountPercentage: Int
    let restaurantId: String            
    let validFrom: Date?
    let validTo: Date?
    let createdAt: Date?

    init?(doc: DocumentSnapshot) {
        let d = doc.data() ?? [:]

        guard
            let title = d["title"] as? String,
            let desc  = d["description"] as? String,
            let image = d["image"] as? String
        else { return nil }

        self.id = doc.documentID
        self.title = title
        self.description = desc
        self.image = image
        self.tags = d["tags"] as? [String] ?? []

        if let p = d["discount_percentage"] as? Int {
            self.discountPercentage = p
        } else if let p = d["discount_percentage"] as? NSNumber {
            self.discountPercentage = p.intValue
        } else {
            self.discountPercentage = 0
        }

        let rawRid = (d["restaurant_id"] as? String) ?? (d["restaurantId"] as? String) ?? ""
        self.restaurantId = Offer.normalizeRestaurantId(rawRid)

        if let ts = d["valid_from"] as? Timestamp { self.validFrom = ts.dateValue() } else { self.validFrom = nil }
        if let ts = d["valid_to"]   as? Timestamp { self.validTo   = ts.dateValue() } else { self.validTo   = nil }
        if let ts = d["createdAt"]  as? Timestamp { self.createdAt = ts.dateValue() } else { self.createdAt = nil }
    }

    private static func normalizeRestaurantId(_ v: String) -> String {
        guard !v.isEmpty else { return "" }
        if let last = v.split(separator: "/").last { return String(last) }
        return v
    }
}
