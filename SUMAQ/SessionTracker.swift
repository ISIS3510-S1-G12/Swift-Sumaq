import Foundation
import FirebaseAnalytics

class SessionTracker: ObservableObject {
    static let shared = SessionTracker()
    
    private var sessionStartTime: Date?
    private var sessionTimer: Timer?
    private var totalSessionTime: TimeInterval = 0
    private var isSessionActive = false
    
    private init() {
        setupNotificationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Session Management
    
    func startSession() {
        guard !isSessionActive else { return }
        
        sessionStartTime = Date()
        totalSessionTime = 0
        isSessionActive = true
        
        // Enviar evento de inicio de sesión
        Analytics.logEvent("session_start", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970),
            "session_id": UUID().uuidString
        ])
        
        print("🔍 SessionTracker: Session started")
    }
    
    func endSession() {
        guard isSessionActive, let startTime = sessionStartTime else { return }
        
        let sessionDuration = Date().timeIntervalSince(startTime)
        totalSessionTime += sessionDuration
        
        // Enviar evento de fin de sesión con duración
        Analytics.logEvent("session_end", parameters: [
            "session_duration_seconds": Int(sessionDuration),
            "total_session_time": Int(totalSessionTime),
            "timestamp": Int(Date().timeIntervalSince1970)
        ])
        
        print("🔍 SessionTracker: Session ended - Duration: \(Int(sessionDuration))s")
        
        sessionStartTime = nil
        isSessionActive = false
    }
    
    func pauseSession() {
        guard isSessionActive, let startTime = sessionStartTime else { return }
        
        let sessionDuration = Date().timeIntervalSince(startTime)
        totalSessionTime += sessionDuration
        
        Analytics.logEvent("session_pause", parameters: [
            "session_duration_seconds": Int(sessionDuration),
            "timestamp": Int(Date().timeIntervalSince1970)
        ])
        
        print("🔍 SessionTracker: Session paused - Duration: \(Int(sessionDuration))s")
        
        sessionStartTime = nil
    }
    
    func resumeSession() {
        guard isSessionActive else { return }
        
        sessionStartTime = Date()
        
        Analytics.logEvent("session_resume", parameters: [
            "timestamp": Int(Date().timeIntervalSince1970)
        ])
        
        print("🔍 SessionTracker: Session resumed")
    }
    
    // MARK: - Screen Tracking
    
    func trackScreenView(_ screenName: String, category: String? = nil) {
        var parameters: [String: Any] = [
            "screen_name": screenName,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        if let category = category {
            parameters["screen_category"] = category
        }
        
        Analytics.logEvent("screen_view", parameters: parameters)
        
        print("🔍 SessionTracker: Screen view - \(screenName)\(category != nil ? " (\(category!))" : "")")
    }
    
    func trackScreenEnd(_ screenName: String, duration: TimeInterval, category: String? = nil) {
        var parameters: [String: Any] = [
            "screen_name": screenName,
            "screen_duration_seconds": Int(duration),
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        if let category = category {
            parameters["screen_category"] = category
        }
        
        Analytics.logEvent("screen_end", parameters: parameters)
        
        print("🔍 SessionTracker: Screen end - \(screenName)\(category != nil ? " (\(category!))" : ""), Duration: \(Int(duration))s")
    }
    
    // MARK: - User Engagement
    
    func trackUserEngagement(_ action: String, parameters: [String: Any] = [:]) {
        var eventParams: [String: Any] = [
            "action": action,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        eventParams.merge(parameters) { (_, new) in new }
        
        Analytics.logEvent("user_engagement", parameters: eventParams)
        
        print("🔍 SessionTracker: User engagement - \(action)")
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        pauseSession()
    }
    
    @objc private func appWillEnterForeground() {
        resumeSession()
    }
    
    @objc private func appWillTerminate() {
        endSession()
    }
}