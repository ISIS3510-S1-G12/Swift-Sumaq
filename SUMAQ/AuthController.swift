import Foundation

final class AuthController: ObservableObject {
    @Published var isLoading = false
    @Published var errorMsg: String?
    @Published var goToLogin = false

    // Registro usuario
    func registerUser(name: String,
                      email: String,
                      password: String,
                      budget: Int,
                      diet: String,
                      profilePicture: String,
                      profileImageData: Data? = nil) {
        isLoading = true; errorMsg = nil
        register(email: email, password: password, name: name, role: .user,
                 budget: budget, diet: diet, profilePicture: profilePicture,
                 profileImageData: profileImageData) { [weak self] res in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch res {
                case .success:
                    NotificationCenter.default.post(name: .authDidRegister,
                                                    object: nil,
                                                    userInfo: ["role": "user"])
                    self.goToLogin = true
                case .failure(let e):
                    self.errorMsg = e.localizedDescription
                    NotificationCenter.default.post(name: .authDidFail,
                                                    object: nil,
                                                    userInfo: ["message": e.localizedDescription])
                }
            }
        }
    }

    // Registro restaurante
    func registerRestaurant(name: String,
                            email: String,
                            password: String,
                            address: String,
                            opening: Int,
                            closing: Int,
                            imageUrl: String,                
                            typeOfFood: String,
                            offer: Bool,
                            rating: Double,
                            busiest: [String:String],
                            restaurantImageData: Data? = nil) { // NUEVO
        isLoading = true; errorMsg = nil
        register(email: email, password: password, name: name, role: .restaurant,
                 address: address, openingTime: opening, closingTime: closing,
                 imageUrl: imageUrl, restaurantImageData: restaurantImageData,
                 typeOfFood: typeOfFood, offer: offer, rating: rating, busiest_hours: busiest) { [weak self] res in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch res {
                case .success:
                    NotificationCenter.default.post(name: .authDidRegister,
                                                    object: nil,
                                                    userInfo: ["role": "restaurant"])
                    self.goToLogin = true
                case .failure(let e):
                    self.errorMsg = e.localizedDescription
                    NotificationCenter.default.post(name: .authDidFail,
                                                    object: nil,
                                                    userInfo: ["message": e.localizedDescription])
                }
            }
        }
    }
}
