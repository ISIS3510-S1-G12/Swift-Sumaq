//
//  MapController.swift
//  SUMAQ
//
//  Multithreading - Strategy #3 Swift Concurrency (async/await) : Maria
//  ---------------------------------------------------------------------
//
//  - The controller now uses a Throwing TaskGroup to resolve restaurant addresses
//    concurrently with a small, controlled degree of parallelism (maxConcurrent).
//  - UI mutations (@Published properties) are funneled through `await MainActor.run { ... }`.
//  - A lightweight `actor` guards the coordinate cache to make reads/writes safe across tasks.
//  - Each geocoding task uses its own `CLGeocoder` instance (Apple recommends one request
//    at a time per geocoder); this allows multiple concurrent requests safely.
//  - Using TaskGroup provides true parallelism on multi-core devices while keeping code
//    structured and cancellable.
//

import Foundation
import MapKit
import CoreLocation

final class MapController: ObservableObject {
    @Published var annotations: [MKPointAnnotation] = []
    @Published var center: CLLocationCoordinate2D? = nil
    @Published var errorMsg: String?

    private let repo: RestaurantsRepositoryType

    // Actor-protected in-memory cache. Using an actor avoids data races when multiple
    // tasks read/write the cache concurrently.
    private static let coordCache = CoordCache()

    init(repo: RestaurantsRepositoryType = RestaurantsRepository()) {
        self.repo = repo
    }

    /// Loads restaurants and places map annotations.
    /// Uses a TaskGroup to geocode multiple addresses concurrently while keeping UI updates on the main actor.
    func loadRestaurants() async {
        let t0 = Date()

        do {
            let list = try await repo.all()

            // Prepare a small, bounded parallelism (helps with CLGeocoder rate limits).
            let maxConcurrent = 4
            var index = 0
            let total = list.count

            // Collect results as (restaurant, coordinate?), then build annotations on main.
            var coords: [(Restaurant, CLLocationCoordinate2D)] = []
            coords.reserveCapacity(total)

            // Use a throwing task group so any thrown error cancels siblings if needed.
            try await withThrowingTaskGroup(of: (Restaurant, CLLocationCoordinate2D?).self) { group in
                // Seed up to maxConcurrent tasks.
                while index < min(maxConcurrent, total) {
                    let r = list[index]; index += 1
                    group.addTask { try await Self.resolveCoordinate(for: r) }
                }

                // Consume results as they come in; for each completed task, enqueue the next.
                while let (restaurant, coordOpt) = try await group.next() {
                    if let c = coordOpt {
                        coords.append((restaurant, c))
                    }
                    if index < total {
                        let next = list[index]; index += 1
                        group.addTask { try await Self.resolveCoordinate(for: next) }
                    }
                }
            }

            // Build annotations and publish on main thread.
            await MainActor.run {
                var pins: [MKPointAnnotation] = []
                pins.reserveCapacity(coords.count)

                var firstCoord: CLLocationCoordinate2D?
                for (r, c) in coords {
                    if firstCoord == nil { firstCoord = c }
                    let a = MKPointAnnotation()
                    a.coordinate = c
                    a.title = r.name
                    a.subtitle = r.typeOfFood
                    pins.append(a)
                }

                self.annotations = pins
                self.center = firstCoord ?? CLLocationCoordinate2D(latitude: 4.6010, longitude: -74.0661)

                let ms = Int(Date().timeIntervalSince(t0) * 1000)
                AnalyticsService.shared.log(EventName.mapPinsLoaded, ["count": pins.count, "load_ms": ms])
            }

        } catch {
            await MainActor.run {
                // UPDATE: When remote fetch fails (offline), also clear pins and center so the UI
                // UPDATE: can detect the absence of valid map data and show the offline message.
                self.errorMsg = error.localizedDescription // UPDATE: Preserve previous behavior (surface error).
                self.annotations = []                      // UPDATE: Clear stale annotations to avoid showing old pins.
                self.center = nil                          // UPDATE: Clear center so HomeUserView won't render the map.
            }
        }
    }

    // MARK: - Per-restaurant coordinate resolution (runs off main)

    /// Resolves a coordinate for a restaurant:
    /// 1) Normalizes address
    /// 2) Checks actor-protected cache
    /// 3) Geocodes with a fresh CLGeocoder if miss
    /// 4) Stores in cache and returns the coordinate
    private static func resolveCoordinate(for r: Restaurant) async throws -> (Restaurant, CLLocationCoordinate2D?) {
        guard let raw = r.address?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return (r, nil)
        }
        let addr = raw

        // Fast path: cache
        if let cached = await coordCache.get(addr) {
            return (r, cached)
        }

        // Miss: geocode with a fresh geocoder instance (safe to run in parallel).
        let coord = try await geocode(addr)

        if let c = coord {
            await coordCache.set(addr, value: c)
            // Small delay to respect potential rate limiting when performing fresh geocodes.
            try? await Task.sleep(nanoseconds: 120_000_000) // ~0.12s
        }

        return (r, coord)
    }

    /// Geocode helper using a *fresh* CLGeocoder per call.
    /// Using a new instance per request allows safe parallel geocoding across tasks.
    private static func geocode(_ address: String) async throws -> CLLocationCoordinate2D? {
        try await withCheckedThrowingContinuation { cont in
            let geocoder = CLGeocoder()
            geocoder.geocodeAddressString(address) { placemarks, error in
                if let error {
                    cont.resume(throwing: error)
                    return
                }
                cont.resume(returning: placemarks?.first?.location?.coordinate)
            }
        }
    }
}

// MARK: - Actor-protected cache

/// Simple actor that serializes access to a String -> CLLocationCoordinate2D dictionary.
private actor CoordCache {
    private var dict: [String: CLLocationCoordinate2D] = [:]

    func get(_ key: String) -> CLLocationCoordinate2D? {
        dict[key]
    }

    func set(_ key: String, value: CLLocationCoordinate2D) {
        dict[key] = value
    }
}
