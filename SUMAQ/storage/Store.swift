import Foundation
 
final class LocalStore {
    static let shared = LocalStore()
 
    let users: UsersDAO
    let restaurants: RestaurantsDAO
    let reviews: ReviewsDAO
    let favorites: FavoritesDAO
 
    private init() {
        self.users = UsersDAO()
        self.restaurants = RestaurantsDAO()
        self.reviews = ReviewsDAO()
        self.favorites = FavoritesDAO()    // 👈 ahora sí inicializado
    }
 
    func configureIfNeeded() {
        do { try LocalDatabase.shared.configure() } catch { print("Local DB configure error: \(error)") }
    }
}
