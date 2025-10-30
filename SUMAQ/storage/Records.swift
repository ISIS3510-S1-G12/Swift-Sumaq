import Foundation

// USERS (schema local; algunos campos no existen en AppUser y quedan en nil/default)
struct UserRecord: Equatable {
    var id: String
    var name: String
    var email: String
    var role: String                 // no viene en AppUser → usamos "user"
    var budget: Int?                 // no viene en AppUser
    var diet: String?                // no viene en AppUser
    var profilePictureURL: String?
    var createdAt: Date?             // no viene en AppUser
    var updatedAt: Date?             // no viene en AppUser
}

// RESTAURANTS
struct RestaurantRecord: Equatable {
    var id: String
    var name: String
    var typeOfFood: String
    var rating: Double
    var offer: Bool
    var address: String?
    var openingTime: Int?
    var closingTime: Int?
    var imageUrl: String?
    var lat: Double?
    var lon: Double?
    var updatedAt: Date?
}

// REVIEWS
struct ReviewRecord: Equatable {
    var id: String
    var userId: String
    var restaurantId: String
    var stars: Int
    var comment: String
    var imageUrl: String?
    var createdAt: Date?
}

// FAVORITES (tabla nueva, PK compuesta userId+restaurantId)
struct FavoriteRecord: Equatable {
    var userId: String
    var restaurantId: String
    var addedAt: Date?
}

// MARK: - Mapping domain → records

extension UserRecord {
    init(from user: AppUser) {
        self.id = user.id
        self.name = user.name
        self.email = user.email
        self.role = "user"                   // AppUser no trae role → default consistente con DB
        self.budget = nil                    // AppUser no trae preferences.budget
        self.diet = nil                      // AppUser no trae preferences.diet
        self.profilePictureURL = user.profilePictureURL
        self.createdAt = nil                 // AppUser no trae createdAt/updatedAt
        self.updatedAt = nil
    }
}

extension RestaurantRecord {
    init(from r: Restaurant) {
        self.id = r.id
        self.name = r.name
        self.typeOfFood = r.typeOfFood
        self.rating = r.rating
        self.offer = r.offer
        self.address = r.address
        self.openingTime = r.opening_time
        self.closingTime = r.closing_time
        self.imageUrl = r.imageUrl
        self.lat = r.lat
        self.lon = r.lon
        
    }
}

extension ReviewRecord {
    init(from r: Review) {
        self.id = r.id
        self.userId = r.userId
        self.restaurantId = r.restaurantId
        self.stars = r.stars
        self.comment = r.comment
        self.imageUrl = r.imageURL
        self.createdAt = r.createdAt
    }
}
