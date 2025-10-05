//
//  AppRestaurant.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//

import Foundation
import FirebaseFirestore

struct AppRestaurant: Identifiable {
    let id: String
    let name: String
    let imageUrl: String?

    init?(doc: DocumentSnapshot) {
        let d = doc.data() ?? [:]
        guard let name = d["name"] as? String else { return nil }
        self.id = doc.documentID
        self.name = name
        self.imageUrl = d["imageUrl"] as? String
    }
}
