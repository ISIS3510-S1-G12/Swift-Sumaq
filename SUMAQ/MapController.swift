//
//  MapController.swift
//  SUMAQ
//

import Foundation
import MapKit
import CoreLocation

/// PURPOSE:
/// Manages map-related data: loads restaurants, geocodes addresses, builds MKPointAnnotations, and exposes
/// @Published state for SwiftUI to render.
///
/// STRATEGY OVERVIEW (used in this file):
/// - MARK: Strategy #2 (GCD / DispatchQueue): Dedicated background queues for geocoding/processing.
/// - MARK: Strategy #3 (Swift Concurrency - async/await): Async functions that suspend without blocking; UI updates via MainActor/DispatchQueue.main.
/// - MARK: Strategy #4 (Structured Concurrency - TaskGroup): Parallel per-restaurant processing then merge results safely.

final class MapController: ObservableObject {
    @Published var annotations: [MKPointAnnotation] = []
    @Published var center: CLLocationCoordinate2D? = nil
    @Published var errorMsg: String?

    private let repo: RestaurantsRepositoryType
    private let geocoder = CLGeocoder()
    
    // MARK: Strategy #2 — GCD / DispatchQueue
    private static let coordCache: NSCache<NSString, NSValue> = {
        let cache = NSCache<NSString, NSValue>()
        cache.countLimit = 500
        cache.totalCostLimit = 1024 * 1024 * 2 // ~2MB
        return cache
    }()
    
    // MARK: Strategy #2 — GCD / DispatchQueue
    private let geocodingQueue = DispatchQueue(label: "com.sumaq.map.geocoding", qos: .userInitiated)
    private let processingQueue = DispatchQueue(label: "com.sumaq.map.processing", qos: .userInitiated)
    
    private var pendingGeocodeWorkItem: DispatchWorkItem?

    init(repo: RestaurantsRepositoryType = RestaurantsRepository()) {
        self.repo = repo
    }

    // MARK: Strategy #3 — Swift Concurrency (async/await)
    func loadRestaurants() async {
        let t0 = Date()
        
        // MARK: Strategy #4 — Structured Concurrency (TaskGroup)
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                guard let self else { return }
                await self.performLoadRestaurants(t0: t0)
            }
        }
    }
    
    // MARK: Strategy #3 + #4
    private func performLoadRestaurants(t0: Date) async {
        do {
            let list = try await repo.all()
            
            await withTaskGroup(of: (MKPointAnnotation?, CLLocationCoordinate2D?).self) { group in
                var pins: [MKPointAnnotation] = []
                var firstCoord: CLLocationCoordinate2D?
                let lock = NSLock()
                
                for restaurant in list {
                    group.addTask { [weak self] in
                        guard let self else { return (nil, nil) }
                        return await self.processRestaurant(restaurant)
                    }
                }
                
                for await result in group {
                    let (annotation, coord) = result
                    if let annotation {
                        lock.lock()
                        pins.append(annotation)
                        if firstCoord == nil, let coord {
                            firstCoord = coord
                        }
                        lock.unlock()
                    }
                }
                
                let finalCenter = firstCoord ?? CLLocationCoordinate2D(latitude: 4.6010, longitude: -74.0661)
                let ms = Int(Date().timeIntervalSince(t0) * 1000)
                
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.annotations = pins
                    self.center = finalCenter
                    AnalyticsService.shared.log(EventName.mapPinsLoaded, ["count": pins.count, "load_ms": ms])
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMsg = error.localizedDescription
            }
        }
    }
    
    // MARK: Strategy #3 + #4
    private func processRestaurant(_ restaurant: Restaurant) async -> (MKPointAnnotation?, CLLocationCoordinate2D?) {
        if let lat = restaurant.lat, let lon = restaurant.lon {
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let annotation = createAnnotation(for: restaurant, coordinate: coord)
            return (annotation, coord)
        }
        
        guard let address = restaurant.address?.trimmingCharacters(in: .whitespacesAndNewlines),
              !address.isEmpty else {
            return (nil, nil)
        }
        
        if let cachedValue = Self.coordCache.object(forKey: address as NSString) {
            let coord = cachedValue.mkCoordinateValue
            let annotation = createAnnotation(for: restaurant, coordinate: coord)
            return (annotation, coord)
        }
        
        let coord = await geocodeAddress(address)
        
        if let coord {
            let value = NSValue(mkCoordinate: coord)
            Self.coordCache.setObject(value, forKey: address as NSString)
            let annotation = createAnnotation(for: restaurant, coordinate: coord)
            return (annotation, coord)
        }
        
        return (nil, nil)
    }
    
    private func createAnnotation(for restaurant: Restaurant, coordinate: CLLocationCoordinate2D) -> MKPointAnnotation {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = restaurant.name
        annotation.subtitle = restaurant.typeOfFood
        return annotation
    }

    // MARK: Strategy #2 — GCD + bridging callback API to async/await
    private func geocodeAddress(_ address: String) async -> CLLocationCoordinate2D? {
        return await withCheckedContinuation { continuation in
            geocodingQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // NOTE: Local semaphore limits concurrency in this block only.
                let semaphore = DispatchSemaphore(value: 5)
                semaphore.wait()
                
                self.geocoder.geocodeAddressString(address) { placemarks, error in
                    semaphore.signal()
                    if let error {
                        print("Geocoding error for \(address): \(error.localizedDescription)")
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: placemarks?.first?.location?.coordinate)
                }
            }
        }
    }
    
    // MARK: Strategy #2 — GCD throttling hook from view-layer
    func handleRegionChange(region: MKCoordinateRegion) {
        pendingGeocodeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.processRegionChange(region: region)
        }
        pendingGeocodeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    private func processRegionChange(region: MKCoordinateRegion) {
        processingQueue.async {
            // Heavy filtering/clustering can happen here.
            // DispatchQueue.main.async { [weak self] in /* publish UI state */ }
        }
    }
    
    func clearCache() {
        Self.coordCache.removeAllObjects()
    }
}

// MARK: Helper for NSCache coordinate storage
private extension NSValue {
    convenience init(mkCoordinate: CLLocationCoordinate2D) {
        self.init(mkCoordinate: mkCoordinate)
    }
    var mkCoordinateValue: CLLocationCoordinate2D { self.mkCoordinateValue }
}
