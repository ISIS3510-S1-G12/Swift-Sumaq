//
//  OSMMarkView.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 19/09/25.
//

import SwiftUI
import MapKit

struct OSMMapView: UIViewRepresentable {
    var annotations: [MKAnnotation] = []
    var center: CLLocationCoordinate2D? = nil
    var span: MKCoordinateSpan? = nil
    var showsUserLocation: Bool = true

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = showsUserLocation

        // OSM tiles
        let template = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = true
        map.addOverlay(overlay, level: .aboveLabels)

        // Atribución (obligatoria)
        let label = UILabel()
        label.text = "© OpenStreetMap contributors"
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        map.addSubview(label)
        NSLayoutConstraint.activate([
            label.trailingAnchor.constraint(equalTo: map.trailingAnchor, constant: -8),
            label.bottomAnchor.constraint(equalTo: map.bottomAnchor, constant: -8)
        ])

        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let coordinator = context.coordinator
        let previous = coordinator.previousAnnotations

        // Calcular diferencias de annotations para evitar removals/añadidos masivos
        let annotationsToRemove: [MKAnnotation] = previous.filter { oldAnnotation in
            !annotations.contains { newAnnotation in
                newAnnotation.coordinate.latitude == oldAnnotation.coordinate.latitude &&
                newAnnotation.coordinate.longitude == oldAnnotation.coordinate.longitude
            }
        }

        let annotationsToAdd: [MKAnnotation] = annotations.filter { newAnnotation in
            !previous.contains { oldAnnotation in
                newAnnotation.coordinate.latitude == newAnnotation.coordinate.latitude &&
                newAnnotation.coordinate.longitude == newAnnotation.coordinate.longitude
            }
        }

        if !annotationsToRemove.isEmpty {
            map.removeAnnotations(annotationsToRemove)
        }
        if !annotationsToAdd.isEmpty {
            map.addAnnotations(annotationsToAdd)
        }

        // Actualizar tracking
        coordinator.previousAnnotations = annotations

        // Actualizar región solo si hay un cambio significativo
        if let c = center {
            let span = self.span ?? MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            let newRegion = MKCoordinateRegion(center: c, span: span)

            let currentRegion = map.region
            let currentCenter = currentRegion.center

            // Distancia aproximada entre centros y diferencia de span
            let centerDistance = hypot(
                currentCenter.latitude - newRegion.center.latitude,
                currentCenter.longitude - newRegion.center.longitude
            )
            let spanDiffLat = abs(currentRegion.span.latitudeDelta - newRegion.span.latitudeDelta)
            let spanDiffLon = abs(currentRegion.span.longitudeDelta - newRegion.span.longitudeDelta)

            // Umbral pequeño para evitar setRegion redundantes
            let regionChanged = centerDistance > 0.0005 || spanDiffLat > 0.0005 || spanDiffLon > 0.0005

            if regionChanged {
                map.setRegion(newRegion, animated: false)
            }
        }

        // Sincronizar flag
        map.showsUserLocation = showsUserLocation
    }

    static func dismantleUIView(_ mapView: MKMapView, coordinator: Coordinator) {
        // Cleanup explícito para evitar leaks
        mapView.removeAnnotations(mapView.annotations)
        mapView.removeOverlays(mapView.overlays)
        mapView.delegate = nil
    }

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        // Tracking de las annotations previas
        var previousAnnotations: [MKAnnotation] = []

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
