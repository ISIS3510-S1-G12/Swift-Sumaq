//  SUMAQApp.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 18/09/25.
//

import SwiftUI
import FirebaseCore

// No cambios aquí: inicializa Firebase como siempre
class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    return true
  }
}

@main
struct SUMAQApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

  //  para saber cuándo la app entra/sale de foreground
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      ContentView()   // tu raíz no cambia
    }
    // tracking de sesión
    .onChange(of: scenePhase) { phase in
      switch phase {
      case .active:
        // sesión inicia
        SessionTracker.shared.appBecameActive()
      case .background:
        // sesión termina (se manda duración a Analytics)
        SessionTracker.shared.appEnteredBackground()
      default:
        break
      }
    }
  }
}
