//
//  User.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 24/09/25.
//

enum UserType: String {
    case user
    case restaurant

    init(from raw: String) {
        switch raw.lowercased() {
        case "user", "usuario": self = .user
        case "restaurant", "restaurante": self = .restaurant
        default:
            self = .user    
        }
    }
}
