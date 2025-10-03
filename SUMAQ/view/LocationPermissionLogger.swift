//
//  LocationPermissionLogger.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//


import Foundation
import CoreLocation

final class LocationPermissionLogger: NSObject, CLLocationManagerDelegate {
    static let shared = LocationPermissionLogger()
    private override init() { super.init() }

    private var manager: CLLocationManager?
    private var started = false

    func startObserving() {
        guard !started else { return }
        started = true
        let m = CLLocationManager()
        m.delegate = self
        manager = m

        // Loguea estado inicial (no solicita permiso).
        let status = type(of: self).statusToString(CLLocationManager.authorizationStatus())
        let granted = type(of: self).isGranted(CLLocationManager.authorizationStatus())
        AnalyticsService.shared.log(EventName.locationAuth, ["status": status, "granted": granted])
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = type(of: self).statusToString(manager.authorizationStatus)
        let granted = type(of: self).isGranted(manager.authorizationStatus)
        AnalyticsService.shared.log(EventName.locationAuth, ["status": status, "granted": granted])
    }

    private static func statusToString(_ s: CLAuthorizationStatus) -> String {
        switch s {
        case .notDetermined: return "not_determined"
        case .restricted:    return "restricted"
        case .denied:        return "denied"
        case .authorizedAlways: return "authorized_always"
        case .authorizedWhenInUse: return "authorized_when_in_use"
        @unknown default: return "unknown"
        }
    }
    private static func isGranted(_ s: CLAuthorizationStatus) -> Bool {
        s == .authorizedAlways || s == .authorizedWhenInUse
    }
}
