//
//  FavoritesController.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

import Foundation

struct FavoritesStats: Equatable {
    let total: Int
    let withOffers: Int
    let percentWithOffers: Int
    let restaurantsWithOffers: [String]
}

enum FavoritesInsight {
    static func makeStats(from restaurants: [Restaurant]) -> FavoritesStats {
        let total = restaurants.count
        let withOffersList = restaurants.filter { $0.offer }
        let withOffers = withOffersList.count

        let percent: Int
        if total == 0 { percent = 0 }
        else { percent = Int((Double(withOffers) / Double(total)) * 100.0) }

        let names = withOffersList.map { $0.name }
        return FavoritesStats(
            total: total,
            withOffers: withOffers,
            percentWithOffers: percent,
            restaurantsWithOffers: names
        )
    }
}
