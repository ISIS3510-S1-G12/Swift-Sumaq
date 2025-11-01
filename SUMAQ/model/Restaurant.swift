//
//  Restaurant.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//



import Foundation
import FirebaseFirestore

struct Restaurant: Identifiable {
    let id: String
    let name: String
    let typeOfFood: String
    let rating: Double
    let offer: Bool
    let address: String?
    let opening_time: Int?
    let closing_time: Int?
    let imageUrl: String?
    let lat: Double?
    let lon: Double?

    init?(doc: DocumentSnapshot) {
        let d = doc.data() ?? [:]
        guard let name = d["name"] as? String else { return nil }

        self.id = doc.documentID
        self.name = name
        self.typeOfFood = (d["typeOfFood"] as? String) ?? ""
        if let r = d["rating"] as? Double { self.rating = r }
        else if let r = d["rating"] as? NSNumber { self.rating = r.doubleValue }
        else { self.rating = 0.0 }

        self.offer = (d["offer"] as? Bool) ?? false
        self.address = d["address"] as? String
        self.opening_time = d["opening_time"] as? Int
        self.closing_time = d["closing_time"] as? Int
        self.imageUrl = d["imageUrl"] as? String

        if let la = d["lat"] as? Double { self.lat = la }
        else if let la = d["lat"] as? NSNumber { self.lat = la.doubleValue }
        else { self.lat = nil }

        if let lo = d["lon"] as? Double { self.lon = lo }
        else if let lo = d["lon"] as? NSNumber { self.lon = lo.doubleValue }
        else { self.lon = nil }
    }
}
