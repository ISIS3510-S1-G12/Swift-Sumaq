//
//  SessionController.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class SessionController: ObservableObject {

    static let shared = SessionController()

    @Published private(set) var firebaseUid: String?
    @Published private(set) var currentUser: AppUser?          // cuando rol = .user
    @Published private(set) var currentRestaurant: AppRestaurant? // cuando rol = .restaurant
    @Published private(set) var role: UserType?                 // .user | .restaurant
    @Published private(set) var isAuthenticated = false

    private var authHandle: AuthStateDidChangeListenerHandle?

    private init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
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

    deinit {
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
    }

    private func resolveRoleAndLoadProfile(uid: String) {
        let db = Firestore.firestore()

        // 1) ¿Existe en Users?
        db.collection("Users").document(uid).getDocument { [weak self] snap, _ in
            guard let self else { return }

            if let snap, snap.exists, let appUser = AppUser(doc: snap) {
                self.role = .user
                self.currentUser = appUser
                self.currentRestaurant = nil
                return
            }

            // 2) Si no, se asume restaurante (documentId = uid)
            db.collection("Restaurants").document(uid).getDocument { [weak self] rdoc, _ in
                guard let self else { return }
                if let rdoc, rdoc.exists, let appRest = AppRestaurant(doc: rdoc) {
                    self.role = .restaurant
                    self.currentRestaurant = appRest
                    self.currentUser = nil
                } else {
                    // Fallback: sin perfil; deja rol nulo
                    self.role = nil
                    self.currentRestaurant = nil
                    self.currentUser = nil
                }
            }
        }
    }

    /// Recarga explícita del perfil de usuario.
    func reloadCurrentUser() {
        guard let uid = firebaseUid, role == .user else { return }
        Firestore.firestore().collection("Users").document(uid).getDocument { [weak self] snap, _ in
            guard let self else { return }
            if let snap, let app = AppUser(doc: snap) {
                self.currentUser = app
            }
        }
    }

    /// Recarga explícita del perfil de restaurante.
    func reloadCurrentRestaurant() {
        guard let uid = firebaseUid, role == .restaurant else { return }
        Firestore.firestore().collection("Restaurants").document(uid).getDocument { [weak self] snap, _ in
            guard let self else { return }
            if let snap, let app = AppRestaurant(doc: snap) {
                self.currentRestaurant = app
            }
        }
    }
}
