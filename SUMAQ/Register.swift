import FirebaseAuth
import FirebaseFirestore

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

/// Registra usuario o restaurante con los campos actualizados para Restaurants.
func register(
    email: String,
    password: String,
    name: String,
    role: UserType,
    // --- SOLO RESTAURANT ---
    address: String? = nil,
    openingTime: Int? = nil,
    closingTime: Int? = nil,
    imageUrl: String? = nil,
    typeOfFood: String? = nil,
    offer: Bool? = nil,
    rating: Double? = nil,
    busiest_hours: [String:String]? = nil,
    // --- SOLO USER ---
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

        // Campos comunes
        var base: [String: Any] = [
            "name": name,
            "email": email,
            "role": (role == .user ? "user" : "restaurant"),
            "ownerUid": uid,
            "created_at": FieldValue.serverTimestamp(),
            "updated_at": FieldValue.serverTimestamp()
        ]

        if role == .user {
            // ----- USERS -----
            base["preferences"] = [
                "budget": budget ?? 0,
                "diet": diet ?? "none",
                "profile_picture": profilePicture ?? ""
            ]
            base["favorite_restaurants"] = []
        } else {
            // ----- RESTAURANTS (claves alineadas con tus screenshots) -----
            base["address"]        = address ?? ""
            base["opening_time"]   = openingTime ?? 0
            base["closing_time"]   = closingTime ?? 0
            base["imageUrl"]       = imageUrl ?? ""
            base["typeOfFood"]     = typeOfFood ?? ""
            base["offer"]          = offer ?? false
            base["rating"]         = rating ?? 0.0     // número, no string
            base["busiest_hours"]  = busiest_hours ?? [:]
            //  ya vive password en FirebaseAuth.
        }

        db.collection(collection).document(uid).setData(base) { e in
            if let e = e { completion(.failure(.firestore(e.localizedDescription))) }
            else { completion(.success(())) }
        }
    }
}
