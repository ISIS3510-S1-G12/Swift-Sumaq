import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage  // necesario

enum RegisterError: LocalizedError {
    case auth(String)
    case firestore(String)
    case storage(String)
    case noUID

    var errorDescription: String? {
        switch self {
        case .auth(let m): return m
        case .firestore(let m): return m
        case .storage(let m): return m
        case .noUID: return "No se obtuvo UID del usuario."
        }
    }
}


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
    restaurantImageData: Data? = nil,        //imagen local desde el dispositivo
    typeOfFood: String? = nil,
    offer: Bool? = nil,
    rating: Double? = nil,
    busiest_hours: [String:String]? = nil,
    // --- SOLO USER ---
    budget: Int? = nil,
    diet: String? = nil,
    profilePicture: String? = nil,           // opcional (URL remota) — fallback
    profileImageData: Data? = nil,           // NUEVO: imagen local desde el dispositivo
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

        func write(_ body: [String: Any]) {
            db.collection(collection).document(uid).setData(body) { e in
                if let e = e { completion(.failure(.firestore(e.localizedDescription))) }
                else { completion(.success(())) }
            }
        }

        func copyRemoteIfNeeded(remote: String?, to path: String, done: @escaping (String?) -> Void) {
            let trimmed = (remote ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return done(nil) }
            StorageService.shared.copyRemoteImageToStorage(from: trimmed, to: path) { result in
                switch result {
                case .success(let storageURL): done(storageURL)
                case .failure: done(nil)
                }
            }
        }

        if role == .user {
            // ----- USERS -----
            var prefs: [String: Any] = [
                "budget": budget ?? 0,
                "diet": diet ?? "none",
                "profile_picture": ""
            ]
            base["favorite_restaurants"] = [String: Any]()   // mapa vacío

            // 1) Si viene imagen local -> subirla
            if let data = profileImageData, !data.isEmpty {
                StorageService.shared.uploadImageData(
                    data,
                    to: "users/\(uid)/profile.jpg",
                    contentType: "image/jpeg"
                ) { result in
                    switch result {
                    case .success(let url): prefs["profile_picture"] = url
                    case .failure: break
                    }
                    base["preferences"] = prefs
                    write(base)
                }
                return
            }

            // 2) Si viene URL remota -> copiar a Storage
            copyRemoteIfNeeded(remote: profilePicture, to: "users/\(uid)/profile.jpg") { url in
                if let url { prefs["profile_picture"] = url }
                else if let raw = profilePicture, !raw.isEmpty { prefs["profile_picture"] = raw } // fallback
                base["preferences"] = prefs
                write(base)
            }

        } else {
            // ----- RESTAURANTS -----
            base["address"]        = address ?? ""
            base["opening_time"]   = openingTime ?? 0
            base["closing_time"]   = closingTime ?? 0
            base["imageUrl"]       = ""
            base["typeOfFood"]     = typeOfFood ?? ""
            base["offer"]          = offer ?? false
            base["rating"]         = rating ?? 0.0
            base["busiest_hours"]  = busiest_hours ?? [:]

            // 1) Imagen local (picker)
            if let data = restaurantImageData, !data.isEmpty {
                StorageService.shared.uploadImageData(
                    data,
                    to: "restaurants/\(uid)/image1.jpg",
                    contentType: "image/jpeg"
                ) { result in
                    if case .success(let url) = result { base["imageUrl"] = url }
                    write(base)
                }
                return
            }

            // 2) URL remota (fallback)
            copyRemoteIfNeeded(remote: imageUrl, to: "restaurants/\(uid)/image1.jpg") { url in
                if let url { base["imageUrl"] = url }
                else if let raw = imageUrl, !raw.isEmpty { base["imageUrl"] = raw }
                write(base)
            }
        }
    }
}
