import SwiftUI

struct ScreenTrackerModifier: ViewModifier {
    let screenName: String
    let screenCategory: String? // Para categorizar pantallas
    @State private var screenStartTime: Date?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                screenStartTime = Date()
                SessionTracker.shared.trackScreenView(screenName, category: screenCategory)
            }
            .onDisappear {
                if let startTime = screenStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    SessionTracker.shared.trackScreenEnd(screenName, duration: duration, category: screenCategory)
                }
            }
    }
}

extension View {
    func trackScreen(_ screenName: String, category: String? = nil) -> some View {
        self.modifier(ScreenTrackerModifier(screenName: screenName, screenCategory: category))
    }
}