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

    static let shared = SessionController()             // Singleton simple para inyectar donde se necesite

    @Published private(set) var firebaseUid: String?
    @Published private(set) var currentUser: AppUser?  // Sólo aplica si es rol "user" (colección "Users")
    @Published private(set) var role: UserType?        // .user | .restaurant
    @Published private(set) var isAuthenticated = false

    private var authHandle: AuthStateDidChangeListenerHandle?

    private init() {
        // Empieza a observar cambios de sesión
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
                self.role = nil
                NotificationCenter.default.post(name: .authDidLogout, object: nil)
            }
        }
    }

    deinit {
        if let authHandle { Auth.auth().removeStateDidChangeListener(authHandle) }
    }

    /// Intenta determinar si el uid vive en `Users` o en `Restaurants`.
    /// Si es `Users`, carga `AppUser` para exponer favoritos, etc.
    private func resolveRoleAndLoadProfile(uid: String) {
        let db = Firestore.firestore()

        // 1) ¿Existe en Users?
        db.collection("Users").document(uid).getDocument { [weak self] snap, _ in
            guard let self else { return }
            if let snap, snap.exists, let appUser = AppUser(doc: snap) {
                self.role = .user
                self.currentUser = appUser
                return
            }
            // 2) Si no, se asume restaurante
            self.role = .restaurant
            self.currentUser = nil
        }
    }

    /// Forzar recarga del perfil de usuario (ej: tras cambios en Firestore que quieras reflejar).
    func reloadCurrentUser() {
        guard let uid = firebaseUid, role == .user else { return }
        Firestore.firestore().collection("Users").document(uid).getDocument { [weak self] snap, _ in
            guard let self else { return }
            if let snap, let app = AppUser(doc: snap) {
                self.currentUser = app
            }
        }
    }
}
