//
//  SharedNotifications.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//

import Foundation

extension Notification.Name {
    // AUTH (ya usados por tu RegisterView)
    static let authDidRegister          = Notification.Name("authDidRegister")
    static let authDidFail              = Notification.Name("authDidFail")

    // Sesión viva (observer de FirebaseAuth)
    static let authStateDidChange       = Notification.Name("authStateDidChange")
    static let authDidLogin             = Notification.Name("authDidLogin")
    static let authDidLogout            = Notification.Name("authDidLogout")

    // Favoritos del usuario actual cambiaron en Firestore
    static let userFavoritesDidChange   = Notification.Name("userFavoritesDidChange")
}
