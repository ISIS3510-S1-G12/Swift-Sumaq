//
//  OSMMapView.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 19/09/25.
//

import SwiftUI
import MapKit

/// PURPOSE:
/// SwiftUI wrapper around MKMapView with OpenStreetMap tiles, annotations, and region change callbacks.
///
/// STRATEGY OVERVIEW (used in this file):
/// - MARK: Strategy #1 (Closures / Callbacks): `onRegionChange` is an optional callback to notify external observers in a decoupled way.
/// - MARK: Strategy #2 (GCD / DispatchQueue): Throttling region changes using DispatchWorkItem + DispatchQueue to avoid excessive downstream work.
/// UI: The actual map updates occur on the main thread as SwiftUI calls updateUIView from the main run loop.

struct OSMMapView: UIViewRepresentable {
    var annotations: [MKAnnotation] = []
    var center: CLLocationCoordinate2D? = nil
    var span: MKCoordinateSpan? = nil
    var showsUserLocation: Bool = true
    
    // MARK: Strategy #1 — Closures
    var onRegionChange: ((MKCoordinateRegion) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsUserLocation = showsUserLocation

        // OpenStreetMap tiles
        let template = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = true
        map.addOverlay(overlay, level: .aboveLabels)

        // Attribution label (required by OSM usage terms)
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
        // Update annotations on the main thread (SwiftUI calls are already on main).
        map.removeAnnotations(map.annotations)
        map.addAnnotations(annotations)

        if let c = center {
            let span = self.span ?? MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            map.setRegion(MKCoordinateRegion(center: c, span: span), animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onRegionChange: onRegionChange)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var onRegionChange: ((MKCoordinateRegion) -> Void)?
        
        // MARK: Strategy #2 — GCD Throttling
        private var pendingRegionChange: DispatchWorkItem?
        
        init(onRegionChange: ((MKCoordinateRegion) -> Void)?) {
            self.onRegionChange = onRegionChange
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard let callback = onRegionChange else { return }
            pendingRegionChange?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard self != nil else { return }
                callback(mapView.region)
            }
            pendingRegionChange = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
        }
    }
}
