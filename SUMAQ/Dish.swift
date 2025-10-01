//
//  Dish.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//



import Foundation
import FirebaseFirestore

struct Dish: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let price: Double
    let rating: Int
    let imageUrl: String
    let dishType: String
    let dishesTags: [String]
    let restaurantId: String         
    let createdAt: Date?

    init?(doc: DocumentSnapshot) {
        let d = doc.data() ?? [:]
        guard
            let name = d["name"] as? String,
            let description = d["description"] as? String,
            let imageUrl = d["imageUrl"] as? String,
            let restaurantId = d["restaurantId"] as? String
        else { return nil }

        // price puede venir como Int/Double/NSNumber
        if let p = d["price"] as? Double { self.price = p }
        else if let p = d["price"] as? Int { self.price = Double(p) }
        else if let p = d["price"] as? NSNumber { self.price = p.doubleValue }
        else { self.price = 0 }

        // rating como Int/NSNumber
        if let r = d["rating"] as? Int { self.rating = r }
        else if let r = d["rating"] as? NSNumber { self.rating = r.intValue }
        else { self.rating = 0 }

        func tsToDate(_ any: Any?) -> Date? {
            if let t = any as? Timestamp { return t.dateValue() }
            if let d = any as? Date { return d }
            return nil
        }

        self.id = doc.documentID
        self.name = name
        self.description = description
        self.imageUrl = imageUrl
        self.restaurantId = restaurantId
        self.dishType = (d["dishType"] as? String) ?? ""
        self.dishesTags = (d["dishesTags"] as? [String]) ?? []
        self.createdAt = tsToDate(d["createdAt"])
    }

    var asFirestore: [String: Any] {
        [
            "name": name,
            "description": description,
            "price": price,
            "rating": rating,
            "imageUrl": imageUrl,
            "dishType": dishType,
            "dishesTags": dishesTags,
            "restaurantId": restaurantId,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }
}
