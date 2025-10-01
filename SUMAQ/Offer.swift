//
//  Offer.swift
//  SUMAQ
//

import Foundation
import FirebaseFirestore

struct Offer: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let discountPercentage: Int
    let image: String                       // URL http(s) / data:image / nombre de asset
    let restaurantPath: String              // como viene en BD (ej: "/Restaurants/<uid>" o "<uid>")
    let restaurantId: String                // normalizado: solo el UID
    let tags: [String]
    let createdAt: Date?
    let validFrom: Date?
    let validTo: Date?

    init?(doc: DocumentSnapshot) {
        let d = doc.data() ?? [:]
        guard
            let title = d["title"] as? String,
            let description = d["description"] as? String,
            let image = d["image"] as? String
        else { return nil }

        // discount
        if let n = d["discount_percentage"] as? Int { self.discountPercentage = n }
        else if let n = d["discount_percentage"] as? NSNumber { self.discountPercentage = n.intValue }
        else { self.discountPercentage = 0 }

        // fechas
        func toDate(_ any: Any?) -> Date? {
            if let t = any as? Timestamp { return t.dateValue() }
            if let d = any as? Date { return d }
            return nil
        }

        // restaurantId/path (acepta 2 formatos)
        let path = (d["restaurant_id"] as? String) ?? (d["restaurantId"] as? String) ?? ""
        let last = path.split(separator: "/").last.map(String.init) ?? path

        self.id = doc.documentID
        self.title = title
        self.description = description
        self.image = image
        self.restaurantPath = path
        self.restaurantId = last
        self.tags = (d["tags"] as? [String]) ?? []
        self.createdAt = toDate(d["createdAt"])
        self.validFrom  = toDate(d["valid_from"])
        self.validTo    = toDate(d["valid_to"])
    }
}
