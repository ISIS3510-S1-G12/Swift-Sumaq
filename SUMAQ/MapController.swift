// MapController.swift
// SUMAQ

import Foundation
import MapKit
import CoreLocation

final class MapController: ObservableObject {
    @Published var annotations: [MKPointAnnotation] = []
    @Published var center: CLLocationCoordinate2D? = nil
    @Published var errorMsg: String?

    private let repo: RestaurantsRepositoryType
    private let geocoder = CLGeocoder()

    private static var coordCache = [String: CLLocationCoordinate2D]()

    init(repo: RestaurantsRepositoryType = RestaurantsRepository()) {
        self.repo = repo
    }

    @MainActor
    func loadRestaurants() async {
        let t0 = Date()

        do {
            let list = try await repo.all()
            var pins: [MKPointAnnotation] = []
            var firstCoord: CLLocationCoordinate2D?

            for r in list {
                guard let raw = r.address?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !raw.isEmpty else { continue }
                let addr = raw

                var wasCached = false
                let coord: CLLocationCoordinate2D?
                if let cached = Self.coordCache[addr] {
                    coord = cached
                    wasCached = true
                } else {
                    coord = try? await geocode(addr)
                    if let c = coord { Self.coordCache[addr] = c }
                    wasCached = false
                }

                if let c = coord {
                    if firstCoord == nil { firstCoord = c }
                    let a = MKPointAnnotation()
                    a.coordinate = c
                    a.title = r.name
                    a.subtitle = r.typeOfFood
                    pins.append(a)

                    if !wasCached {
                        try? await Task.sleep(nanoseconds: 120_000_000) // 0.12s
                    }
                }
            }

            self.annotations = pins
            self.center = firstCoord ?? CLLocationCoordinate2D(latitude: 4.6010, longitude: -74.0661)

            let ms = Int(Date().timeIntervalSince(t0) * 1000)
            AnalyticsService.shared.log(EventName.mapPinsLoaded, ["count": pins.count, "load_ms": ms])

        } catch {
            self.errorMsg = error.localizedDescription
        }
    }

    private func geocode(_ address: String) async throws -> CLLocationCoordinate2D? {
        try await withCheckedThrowingContinuation { cont in
            geocoder.geocodeAddressString(address) { placemarks, error in
                if let error {
                    cont.resume(throwing: error); return
                }
                cont.resume(returning: placemarks?.first?.location?.coordinate)
            }
        }
    }
}
