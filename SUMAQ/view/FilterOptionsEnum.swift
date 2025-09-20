

import Foundation

enum FilterOptionHomeUserView: String, CaseIterable, Identifiable, Hashable {
    case price        = "Price"
    case typeOfFood   = "Type of Food"
    case withOffer    = "With Offer"
    case withoutOffer = "Without Offer"

    var id: String { rawValue }
}

enum FilterOptionFavoritesView: String, CaseIterable, Identifiable, Hashable {
    case cuisineType   = "Cuisine Type"
    case dateAdded     = "Date Added"
    case openNow       = "Open Now"
    case rating        = "Rating"

    var id: String { rawValue }
}

enum FilterOptionOffersView: String, CaseIterable, Identifiable, Hashable {
    case offerType     = "Offer Type"
    case cuisineType   = "Cuisine Type"
    case discountRange = "Discount Range"
    case dayOfWeek     = "Day of the Week"

    var id: String { rawValue }
}

enum FilterOptionReviewHistoryView: String, CaseIterable, Identifiable, Hashable {
    case dateRange     = "Date Range"
    case ratingGiven   = "Rating Given"
    case cuisineType   = "Cuisine Type"

    var id: String { rawValue }
}


