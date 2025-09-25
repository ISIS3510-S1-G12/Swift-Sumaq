//
//  Register.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 24/09/25.
//

import FirebaseAuth
import FirebaseFirestore
import CoreLocation

enum RegisterError: LocalizedError {
    case auth(String)
    case firestore(String)
    case noUID

    var errorDescription: String? {
        switch self {
        case .auth(let m): return m
        case .firestore(let m): return m
        case .noUID: return "No se obtuvo UID del usuario."
        }
    }
}

func register(email: String,
              password: String,
              name: String,
              role: UserType,
              // solo si es restaurant
              address: String? = nil,
              openingTime: Int? = nil,
              closingTime: Int? = nil,
              location: String? = nil,
              restaurantImage: String? = nil,
              restaurantType: String? = nil,
              busiest_hours: [String:String]? = nil,
              // solo si es usuario
              budget: Int? = nil,
              diet: String? = nil,
              profilePicture: String? = nil,
              completion: @escaping (Result<Void, RegisterError>) -> Void
) {

    Auth.auth().createUser(withEmail: email, password: password) { res, err in
        if let err = err { return completion(.failure(.auth(err.localizedDescription))) }
        guard let uid = res?.user.uid else { return completion(.failure(.noUID)) }

        let db = Firestore.firestore()
        let collection = (role == .user) ? "Users" : "Restaurants"

        var data: [String: Any] = [
            "name": name,
            "email": email,
            "role": (role == .user ? "user" : "restaurant"),
            "created_at": FieldValue.serverTimestamp(),
            "owner_uid": uid
        ]

        if role == .user {
            data["preferences"] = [
                "budget": budget ?? 0,
                "diet": diet ?? "none",
                "profile_picture": profilePicture ?? ""
            ]
            data["favorite_restaurants"] = [DocumentReference]()
        } else {
            data["address"] = address ?? ""
            data["oppenning_time"] = openingTime ?? 0
            data["closing_time"] = closingTime ?? 0
            data["restaurant_image"] = restaurantImage ?? ""
            data["restaurant_type"] = restaurantType ?? ""
            data["location"] = location ?? ""
            data["busiest_hours"] = busiest_hours ?? [:]        
        }

        db.collection(collection).document(uid).setData(data) { e in
            if let e = e { completion(.failure(.firestore(e.localizedDescription))) }
            else { completion(.success(())) }
        }
    }
}
