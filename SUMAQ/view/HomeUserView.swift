//
//  HomeUser.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 19/09/25.
//
//
//  HomeUser.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 19/09/25.
//

import SwiftUI
import MapKit

// MARK: - Home (sin navegación)
struct UserHomeView: View {
    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionHomeUserView? = nil
    @State private var selectedTab = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TopBar()
                SegmentedTabs(selectedIndex: $selectedTab)

                SearchFilterChatBar<FilterOptionHomeUserView>(
                    text: $searchText,
                    selectedFilter: $selectedFilter,
                    onChatTap: { /* abrir chatbot */ },
                    config: .init(
                        searchColor: Palette.orange,
                        ringColor:   Palette.orange,
                        diameter:    44,
                        ringLineWidth: 2
                    )
                    // options: [.withOffer, .withoutOffer] // <- (6) subset opcional
                )
                .padding(.horizontal, 16)

                // Mapa OSM (zona Uniandes)
                OSMMapView(center: CLLocationCoordinate2D(latitude: 4.6010, longitude: -74.0661),
                           span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                VStack(spacing: 14) {

                    RestaurantCard(
                        name: "La Puerta",
                        category: "Burgers restaurant",
                        tag: "Offers",
                        rating: 4.5,
                        logoSystemName: "puerta"
                    )


                    NavigationLink {
                        DetailRestauFromUserView()
                    } label: {
                        RestaurantCard(
                            name: "La Puerta",
                            category: "Burgers restaurant",
                            tag: "Offers",
                            rating: 4.5,
                            logoSystemName: "circle"
                        )
                    }
                    .buttonStyle(.plain)
                    RestaurantCard(
                        name: "Chick & Chips",
                        category: "Chicken restaurant",
                        tag: "Offers Tag",
                        rating: 5.0,
                        logoSystemName: "chick"
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

#Preview { UserHomeView() }
