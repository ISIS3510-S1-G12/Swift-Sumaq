//
//  DetalleRestauFromUser.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 20/09/25.
//
// No se usa este archivo actualmente

import Foundation
import SwiftUI
import MapKit

struct DetailRestauFromUserView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: Int = 0
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    TopBar()

                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                            Text("La Puerta")
                                .font(.custom("Montserrat-SemiBold", size: 22))
                        }
                        .foregroundColor(Palette.burgundy)
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)                 
                    .contentShape(Rectangle())
                    RestaurantDetsSegmentedTab(selectedIndex: $selectedTab)
                        .frame(maxWidth: .infinity, alignment: .center)

    
                    // Mapa OSM
                    OSMMapView(
                        center: CLLocationCoordinate2D(latitude: 4.6010, longitude: -74.0661),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                    // Cards
                    VStack(spacing: 12) {
                        Group {
                            RestaurantDishCardGeneral(
                                title: "Extra Bacon",
                                subtitle: "Hamburger with free bacon.",
                                imageName: "offer_lucille",
                                rating: 4.0
                            );
                            
                            RestaurantDishCardGeneral(
                                title: "Bacon Sandwich",
                                subtitle: "Hamburger with a lot of bacon.",
                                imageName: "sandwich",
                                rating: 4
                            );
                            RestaurantDishCardGeneral(
                                title: "BBQ Sandwich",
                                subtitle: "Hamburger with a lot of BBQ.",
                                imageName: "offer_bbq",
                                rating: 4
                            )
                            
                        }
                    }
                    .padding(.horizontal, 16)

                    
                }
                .padding(.top, 8)
            }
            .background(Color.white.ignoresSafeArea())
        }
    }
}


#Preview { DetailRestauFromUserView() }
