import Foundation
import FirebaseAnalytics

final class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}

    private var screenStarts: [String: Date] = [:]
    private let queue = DispatchQueue(label: "analytics.serial")

    func log(_ name: String, _ params: [String: Any] = [:]) {
        Analytics.logEvent(name, parameters: params)
    }

    // MARK: Screen timing
    func screenStart(_ screen: String, extra: [String: Any] = [:]) {
        queue.sync { screenStarts[screen] = Date() }
        var p = extra; p["screen"] = screen
        log(EventName.screenStart, p)
    }

    func screenEnd(_ screen: String, extra: [String: Any] = [:]) {
        let start = queue.sync { screenStarts.removeValue(forKey: screen) }
        var p = extra; p["screen"] = screen
        if let s = start {
            p["duration_ms"] = Int(Date().timeIntervalSince(s) * 1000)
        }
        log(EventName.screenEnd, p)
    }
}
