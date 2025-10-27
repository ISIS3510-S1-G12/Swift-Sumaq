import Foundation
import FirebaseAnalytics

class SessionTracker: ObservableObject {
    static let shared = SessionTracker()
    
    private var sessionStartTime: Date?
    private var sessionTimer: Timer?
    private var totalSessionTime: TimeInterval = 0
    private var isSessionActive = false
    private var visitedRestaurants: Set<String> = []
    
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
        visitedRestaurants.removeAll()
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
            "unique_restaurants_visited": visitedRestaurants.count,
            "timestamp": Int(Date().timeIntervalSince1970)
        ])
        
        print("🔍 SessionTracker: Session ended - Duration: \(Int(sessionDuration))s, Unique restaurants: \(visitedRestaurants.count)")
        
        sessionStartTime = nil
        isSessionActive = false
        visitedRestaurants.removeAll()
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
    
    // MARK: - Restaurant Visit Tracking
    
    func trackRestaurantVisit(restaurantId: String, restaurantName: String) {
        let isNewRestaurant = visitedRestaurants.insert(restaurantId).inserted
        
        var parameters: [String: Any] = [
            "restaurant_id": restaurantId,
            "restaurant_name": restaurantName,
            "is_new_visit": isNewRestaurant,
            "unique_restaurants_in_session": visitedRestaurants.count,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]
        
        Analytics.logEvent("restaurant_visit_session", parameters: parameters)
        
        print("🔍 SessionTracker: Restaurant visit - \(restaurantName) (Total unique: \(visitedRestaurants.count))")
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