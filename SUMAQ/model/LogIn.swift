//
//  LogIn.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 24/09/25.
//

import FirebaseAuth
import FirebaseFirestore

enum AppDestination {
    case userHome
    case restaurantHome
}

enum LoginError: LocalizedError {
    case missingUID
    case auth(String)
    case firestore(String)

    var errorDescription: String? {
        switch self {
        case .missingUID: return "No se obtuvo un UID al iniciar sesión."
        case .auth(let m): return m
        case .firestore(let m): return m
        }
    }
}

func login(email: String,
           password: String,
           completion: @escaping (Result<AppDestination, LoginError>) -> Void) {

    Auth.auth().signIn(withEmail: email, password: password) { res, err in
        if let err = err {
            return completion(.failure(.auth(err.localizedDescription)))
        }
        guard let uid = res?.user.uid else {
            return completion(.failure(.missingUID))
        }

        let db = Firestore.firestore()

        // 1) usuario ?
        db.collection("Users").document(uid).getDocument { snap, err in
            if let err = err {
                return completion(.failure(.firestore(err.localizedDescription)))
            }

            if let snap, snap.exists {
                return completion(.success(.userHome))
            }

            // 2) restaurante?
            db.collection("Restaurants")
                .whereField("owner_uid", isEqualTo: uid)
                .limit(to: 1)
                .getDocuments { qs, err in
                    if let err = err {
                        return completion(.failure(.firestore(err.localizedDescription)))
                    }
                    if let doc = qs?.documents.first, doc.exists {
                        return completion(.success(.restaurantHome))
                    } else {
                        // Fallback si no hay doc
                        return completion(.success(.userHome))
                    }
                }
        }
    }
}
