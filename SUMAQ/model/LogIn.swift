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
    case offlineCredentialsNotFound
    case offlineLoginFailed

    var errorDescription: String? {
        switch self {
        case .missingUID: return "No se obtuvo un UID al iniciar sesión."
        case .auth(let m): return m
        case .firestore(let m): return m
        case .offlineCredentialsNotFound: return "No se encontraron credenciales guardadas para inicio de sesión offline."
        case .offlineLoginFailed: return "No se pudo iniciar sesión offline. Por favor, verifica tu conexión a internet."
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
                // Save offline credentials for future offline login
                KeychainHelper.shared.saveOfflineCredentials(
                    email: email,
                    password: password,
                    uid: uid,
                    role: "user"
                )
                return completion(.success(.userHome))
            }

            // 2) restaurante?
            db.collection("Restaurants")
                .whereField("ownerUid", isEqualTo: uid)  
                .limit(to: 1)
                .getDocuments { qs, err in
                    if let err = err {
                        return completion(.failure(.firestore(err.localizedDescription)))
                    }
                    if let doc = qs?.documents.first, doc.exists {
                        // Save offline credentials for future offline login
                        KeychainHelper.shared.saveOfflineCredentials(
                            email: email,
                            password: password,
                            uid: uid,
                            role: "restaurant"
                        )
                        return completion(.success(.restaurantHome))
                    } else {
                        // Save offline credentials for future offline login
                        KeychainHelper.shared.saveOfflineCredentials(
                            email: email,
                            password: password,
                            uid: uid,
                            role: "user"
                        )
                        return completion(.success(.userHome))
                    }
                }
        }
    }
}

// Offline login function - validates saved credentials when offline
func loginOffline(completion: @escaping (Result<AppDestination, LoginError>) -> Void) {
    // Check if offline credentials exist
    guard let credentials = KeychainHelper.shared.getOfflineCredentials() else {
        return completion(.failure(.offlineCredentialsNotFound))
    }
    
    // Check if Firebase Auth has a persisted session
    if let currentUser = Auth.auth().currentUser, currentUser.uid == credentials.uid {
        // User is already authenticated with matching UID, determine destination based on role
        let destination: AppDestination = credentials.role == "restaurant" ? .restaurantHome : .userHome
        return completion(.success(destination))
    }
    
    // Try to restore session using saved credentials
    // Even without network, Firebase may have persisted auth state
    Auth.auth().useAppLanguage()
    
    // Attempt to sign in (may fail if offline, but Firebase might have cached auth state)
    Auth.auth().signIn(withEmail: credentials.email, password: credentials.password) { result, error in
        if let error = error {
            // Check if it's a network error
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && 
               (nsError.code == NSURLErrorNotConnectedToInternet || 
                nsError.code == NSURLErrorTimedOut ||
                nsError.code == NSURLErrorNetworkConnectionLost) {
                // Network error but we have valid saved credentials - allow offline login
                // Firebase Auth may still have persisted state
                if let currentUser = Auth.auth().currentUser, currentUser.uid == credentials.uid {
                    let destination: AppDestination = credentials.role == "restaurant" ? .restaurantHome : .userHome
                    return completion(.success(destination))
                } else {
                    // No persisted session, but we'll allow offline access with saved credentials
                    let destination: AppDestination = credentials.role == "restaurant" ? .restaurantHome : .userHome
                    return completion(.success(destination))
                }
            } else {
                // Authentication failed - invalid credentials
                return completion(.failure(.offlineLoginFailed))
            }
        }
        
        // Success - credentials are valid
        let destination: AppDestination = credentials.role == "restaurant" ? .restaurantHome : .userHome
        return completion(.success(destination))
    }
}
