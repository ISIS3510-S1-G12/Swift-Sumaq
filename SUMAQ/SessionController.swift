//
//  SessionController.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//

// PURPOSE: Manages Firebase authentication state and user/restaurant profile data
// ROOT CAUSE: @Published properties were updated from Firebase callbacks executing on background threads.
//             SwiftUI requires @Published updates to occur on the main thread/actor for proper observation.
// MULTITHREADING CHANGE: Make class @MainActor and ensure all @Published property mutations happen on main thread.
// MARK: Strategy #3 (Swift Concurrency): @MainActor ensures all state updates are on main thread
// THREADING NOTE: Firebase callbacks are dispatched to MainActor.run before mutating @Published properties

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class SessionController: ObservableObject {

    static let shared: SessionController = {
        let instance = SessionController()
        return instance
    }()

    @Published private(set) var firebaseUid: String?
    @Published private(set) var currentUser: AppUser?          // cuando rol = .user
    @Published private(set) var currentRestaurant: AppRestaurant? // cuando rol = .restaurant
    @Published private(set) var role: UserType?                 // .user | .restaurant
    @Published private(set) var isAuthenticated = false

    private var authHandle: AuthStateDidChangeListenerHandle?

    private init() {
        // Firebase auth state listener callbacks execute on background thread
        // We dispatch state updates to main thread
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            
            // Ensure updates happen on main thread
            Task { @MainActor in
                self.firebaseUid = user?.uid
                self.isAuthenticated = (user != nil)
                NotificationCenter.default.post(name: .authStateDidChange, object: nil)

                if let uid = user?.uid {
                    self.resolveRoleAndLoadProfile(uid: uid)
                    NotificationCenter.default.post(name: .authDidLogin, object: nil, userInfo: ["uid": uid])
                } else {
                    self.currentUser = nil
                    self.currentRestaurant = nil
                    self.role = nil
                    NotificationCenter.default.post(name: .authDidLogout, object: nil)
                }
            }
        }
    }

    deinit {
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
    }

    private func resolveRoleAndLoadProfile(uid: String) {
        let db = Firestore.firestore()

        db.collection("Users").document(uid).getDocument { [weak self] snap, _ in
            guard let self = self else { return }

            Task { @MainActor in
                if let snap, snap.exists, let appUser = AppUser(doc: snap) {
                    self.role = .user
                    self.currentUser = appUser
                    self.currentRestaurant = nil
                    return
                }

                db.collection("Restaurants").document(uid).getDocument { [weak self] rdoc, _ in
                    guard let self = self else { return }
                    
                    Task { @MainActor in
                        if let rdoc, rdoc.exists, let appRest = AppRestaurant(doc: rdoc) {
                            self.role = .restaurant
                            self.currentRestaurant = appRest
                            self.currentUser = nil
                        } else {
                            self.role = nil
                            self.currentRestaurant = nil
                            self.currentUser = nil
                        }
                    }
                }
            }
        }
    }

    func reloadCurrentUser() {
        guard let uid = firebaseUid, role == .user else { return }
        Firestore.firestore().collection("Users").document(uid).getDocument { [weak self] snap, _ in
            guard let self = self else { return }
            Task { @MainActor in
                if let snap, let app = AppUser(doc: snap) {
                    self.currentUser = app
                }
            }
        }
    }

    func reloadCurrentRestaurant() {
        guard let uid = firebaseUid, role == .restaurant else { return }
        Firestore.firestore().collection("Restaurants").document(uid).getDocument { [weak self] snap, _ in
            guard let self = self else { return }
            Task { @MainActor in
                if let snap, let app = AppRestaurant(doc: snap) {
                    self.currentRestaurant = app
                }
            }
        }
    }
}

// MARK: - Session Tracking Extension
extension SessionController {
    func trackUserSession() {
        // Llamar cuando el usuario se autentica
        SessionTracker.shared.startSession()
        SessionTracker.shared.trackUserEngagement("user_login", parameters: [
            "user_type": role?.rawValue ?? "unknown"
        ])
    }
    
    func endUserSession() {
        // Llamar cuando el usuario se desloguea
        SessionTracker.shared.trackUserEngagement("user_logout", parameters: [
            "user_type": role?.rawValue ?? "unknown"
        ])
        SessionTracker.shared.endSession()
    }
    
    func trackUserRoleChange() {
        SessionTracker.shared.trackUserEngagement("role_change", parameters: [
            "new_role": role?.rawValue ?? "unknown"
        ])
    }
}