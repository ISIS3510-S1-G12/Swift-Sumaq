//  SUMAQApp.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 18/09/25.
//

import SwiftUI
import FirebaseCore

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

  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .onChange(of: scenePhase) { phase in
      switch phase {
      case .active:
        SessionTracker.shared.appBecameActive()
      case .background:
        SessionTracker.shared.appEnteredBackground()
      default:
        break
      }
    }
  }
}
