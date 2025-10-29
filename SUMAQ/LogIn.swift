//
//  LogIn.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 24/09/25.
//

// PURPOSE: Login authentication function using Firebase Auth and Firestore
// ROOT CAUSE: Firebase callbacks execute on background threads. The completion handler pattern
//             requires manual dispatch to main thread, which can cause timing issues with SwiftUI updates.
// MULTITHREADING CHANGE: Bridge Firebase callbacks to async/await using withCheckedThrowingContinuation,
//              ensuring all Firestore queries run on background and results return to caller's context.
// MARK: Strategy #3 (Swift Concurrency): Bridges callback-based Firebase APIs to async/await
// THREADING NOTE: Firebase callbacks run on background threads; async bridge allows caller to control dispatch

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

// Legacy completion-based function (kept for backward compatibility)
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
                .whereField("ownerUid", isEqualTo: uid)  
                .limit(to: 1)
                .getDocuments { qs, err in
                    if let err = err {
                        return completion(.failure(.firestore(err.localizedDescription)))
                    }
                    if let doc = qs?.documents.first, doc.exists {
                        return completion(.success(.restaurantHome))
                    } else {
                        return completion(.success(.userHome))
                    }
                }
        }
    }
}

// New async/await version for better concurrency handling
func loginAsync(email: String, password: String) async throws -> AppDestination {
    // Bridge Firebase Auth callback to async/await
    let authResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                continuation.resume(throwing: LoginError.auth(error.localizedDescription))
            } else if let result = result {
                continuation.resume(returning: result)
            } else {
                continuation.resume(throwing: LoginError.missingUID)
            }
        }
    }
    
    guard let uid = authResult.user.uid as String? else {
        throw LoginError.missingUID
    }
    
    let db = Firestore.firestore()
    
    // Bridge Firestore callback to async/await
    let userDoc = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentSnapshot?, Error>) in
        db.collection("Users").document(uid).getDocument { snapshot, error in
            if let error = error {
                continuation.resume(throwing: LoginError.firestore(error.localizedDescription))
            } else {
                continuation.resume(returning: snapshot)
            }
        }
    }
    
    // Check if user document exists
    if let userDoc = userDoc, userDoc.exists {
        return .userHome
    }
    
    // Check restaurant document
    let restaurantQuery = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot?, Error>) in
        db.collection("Restaurants")
            .whereField("ownerUid", isEqualTo: uid)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    continuation.resume(throwing: LoginError.firestore(error.localizedDescription))
                } else {
                    continuation.resume(returning: snapshot)
                }
            }
    }
    
    if let restaurantQuery = restaurantQuery, let doc = restaurantQuery.documents.first, doc.exists {
        return .restaurantHome
    }
    
    // Default to user home if neither found
    return .userHome
}