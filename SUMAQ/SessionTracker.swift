import Foundation

final class SessionTracker {
    static let shared = SessionTracker()
    private init() {}

    private var start: Date?

    func appBecameActive() {
        start = Date()
        AnalyticsService.shared.log(EventName.sessionStart, [:])
    }

    func appEnteredBackground() {
        guard let s = start else { return }
        let ms = Int(Date().timeIntervalSince(s) * 1000)
        AnalyticsService.shared.log(EventName.sessionEnd, ["duration_ms": ms])
        start = nil
    }
}
