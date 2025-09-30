//
//  Offer.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

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
    let image: String
    let restaurantPath: String       // por ej: "/Restaurants/<uid>"
    let tags: [String]
    let validFrom: Date?
    let validTo: Date?
    let createdAt: Date?

    var restaurantId: String {
        // de "/Restaurants/<uid>" extrae "<uid>"
        if let last = restaurantPath.split(separator: "/").last { return String(last) }
        return restaurantPath
    }

    var isActiveNow: Bool {
        let now = Date()
        if let from = validFrom, now < from { return false }
        if let to = validTo, now > to { return false }
        return true
    }
}

extension Offer {
    init?(doc: DocumentSnapshot) {
        let d = doc.data() ?? [:]
        guard
            let title = d["title"] as? String,
            let description = d["description"] as? String,
            let image = d["image"] as? String,
            let restaurantPath = d["restaurant_id"] as? String
        else { return nil }

        // discount puede ser int o double
        var discount = 0
        if let i = d["discount_percentage"] as? Int { discount = i }
        else if let n = d["discount_percentage"] as? NSNumber { discount = n.intValue }

        func tsToDate(_ any: Any?) -> Date? {
            if let t = any as? Timestamp { return t.dateValue() }
            if let d = any as? Date { return d }
            return nil
        }

        self.id = doc.documentID
        self.title = title
        self.description = description
        self.discountPercentage = discount
        self.image = image
        self.restaurantPath = restaurantPath
        self.tags = d["tags"] as? [String] ?? []
        self.validFrom = tsToDate(d["valid_from"])
        self.validTo   = tsToDate(d["valid_to"])
        self.createdAt = tsToDate(d["createdAt"])
    }

    var asFirestore: [String: Any] {
        [
            "title": title,
            "description": description,
            "discount_percentage": discountPercentage,
            "image": image,
            "restaurant_id": restaurantPath,
            "tags": tags,
            "valid_from": validFrom.map { Timestamp(date: $0) } as Any,
            "valid_to": validTo.map { Timestamp(date: $0) } as Any,
            "createdAt": createdAt.map { Timestamp(date: $0) } ?? FieldValue.serverTimestamp()
        ]
    }
}
