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
    
    
    static let userReviewsDidChange     = Notification.Name("userReviewsDidChange")
    static let reviewDidCreate          = Notification.Name("reviewDidCreate")
    
    static let crowdScanDidStart  = Notification.Name("crowdScanDidStart")
    static let crowdScanDidUpdate = Notification.Name("crowdScanDidUpdate") // userInfo["count"] = Int
    static let crowdScanDidFinish = Notification.Name("crowdScanDidFinish") // userInfo["count"] = Int
    }
    

