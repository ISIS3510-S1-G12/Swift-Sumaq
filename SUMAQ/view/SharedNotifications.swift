//
//  SharedNotifications.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//

import Foundation

extension Notification.Name {
    // Auth
    static let authDidRegister        = Notification.Name("AuthDidRegister")
    static let authDidFail            = Notification.Name("AuthDidFail")
    static let authDidLogin           = Notification.Name("AuthDidLogin")

    // Session
    static let sessionUserDidChange   = Notification.Name("SessionUserDidChange")

    // Users / favoritos
    static let userFavoritesDidChange = Notification.Name("UserFavoritesDidChange")
}

