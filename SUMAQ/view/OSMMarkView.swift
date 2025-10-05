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
        map.removeAnnotations(map.annotations)
        map.addAnnotations(annotations)

        if let c = center {
            let span = self.span ?? MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            map.setRegion(MKCoordinateRegion(center: c, span: span), animated: false)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

