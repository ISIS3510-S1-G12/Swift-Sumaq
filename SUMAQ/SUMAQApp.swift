//  SUMAQApp.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 18/09/25.
//

import SwiftUI
import FirebaseCore
import FirebaseAnalytics

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    
    // Habilitar Analytics
    Analytics.setAnalyticsCollectionEnabled(true)
    
    // Configurar parámetros personalizados
    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
      Analytics.setUserProperty(version, forName: "app_version")
    }
    
    // Configurar propiedades del usuario
    Analytics.setUserProperty("ios", forName: "platform")
    
    LocalStore.shared.configureIfNeeded()
    return true
  }
}

@main
struct SUMAQApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  @StateObject private var sessionTracker = SessionTracker.shared

  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      ContentView()
        .onAppear {
          sessionTracker.startSession()
        }
    }
    .onChange(of: scenePhase) { phase in
      switch phase {
      case .active:
        sessionTracker.resumeSession()
      case .background:
        sessionTracker.pauseSession()
      case .inactive:
        sessionTracker.pauseSession()
      @unknown default:
        break
      }
    }
  }
}
