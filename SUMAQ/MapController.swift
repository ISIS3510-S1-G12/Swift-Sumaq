import Foundation
import MapKit
import CoreLocation

final class MapController: ObservableObject {
    @Published var annotations: [MKPointAnnotation] = []
    @Published var center: CLLocationCoordinate2D? = nil
    @Published var errorMsg: String?

    private let repo: RestaurantsRepositoryType
    private let geocoder = CLGeocoder()

    init(repo: RestaurantsRepositoryType = RestaurantsRepository()) {
        self.repo = repo
    }

    /// Carga rrestaurantes y generar pins geocodificando con address.
    @MainActor
    func loadRestaurants() async {
        do {
            let list = try await repo.all()

            var pins: [MKPointAnnotation] = []
            var firstCoord: CLLocationCoordinate2D?

            for r in list {
                guard let addr = r.address, !addr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    continue
                }

                if let c = try? await geocode(addr) {
                    if firstCoord == nil { firstCoord = c }

                    let a = MKPointAnnotation()
                    a.coordinate = c
                    a.title = r.name
                    a.subtitle = r.typeOfFood
                    pins.append(a)

                    // Esto evita throttling de CLGeocoder cuando hay muchas direcciones
                    try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s
                }
            }

            self.annotations = pins
            // Uniandes por defecto
            self.center = firstCoord ?? CLLocationCoordinate2D(latitude: 4.6010, longitude: -74.0661)
        } catch {
            self.errorMsg = error.localizedDescription
        }
    }

    // MARK: - Geocodificación (Address -> Coordenadas)
    private func geocode(_ address: String) async throws -> CLLocationCoordinate2D? {
        try await withCheckedThrowingContinuation { cont in
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
