//
//  RestaurantOffersView.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDO�O on 20/09/25.
//

import SwiftUI
import MapKit

struct OffersContent: View {
    @State private var searchText: String = ""

    var body: some View {
        VStack(spacing: 16) {

            // Header
            RestaurantTopBar(restaurantLogo: "AppLogoUI", appLogo: "AppLogoUI", showBack: true)

            // Mapa OSM
            OSMMapView(
                center: CLLocationCoordinate2D(latitude: 4.6010, longitude: -74.0661),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)

            // Search bar naranja
            HStack {
                Spacer()
                SearchBar(text: $searchText, color: Palette.orangeAlt)
                Spacer()
            }
            .padding(.horizontal, 16)

            // Cards de ofertas
            VStack(spacing: 12) {
                RestaurantDishCard(
                    title: "Extra Bacon",
                    subtitle: "Hamburger with a free bacon addition",
                    imageName: "Dish1",
                    rating: 4
                )
                RestaurantDishCard(
                    title: "Extra BBQ",
                    subtitle: "Hamburger with a free BBQ addition",
                    imageName: "Dish2",
                    rating: 4
                )
            }
            .padding(.horizontal, 16)

            // Botones inferiores (estos sí pueden navegar a pantallas internas)
            HStack(spacing: 12) {
                NavigationLink {
                    NewOfferView()
                } label: {
                    SmallCapsuleButton(
                        title: "New Offer",
                        background: Palette.orangeAlt,
                        textColor: .white
                    )
                }

                NavigationLink {
                    EditOfferView()
                } label: {
                    SmallCapsuleButton(
                        title: "Edit Offer",
                        background: Color.gray.opacity(0.6),
                        textColor: .white
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }
}

// utilidades locales 
private struct SmallCapsuleButton: View {
    let title: String
    let background: Color
    let textColor: Color

    var body: some View {
        Text(title)
            .font(.custom("Montserrat-SemiBold", size: 14))
            .foregroundColor(textColor)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(background)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
    }
}

struct NewOfferView: View {
    var body: some View {
        Text("New Offer")
            .font(.title)
            .padding()
    }
}

struct EditOfferView: View {
    var body: some View {
        Text("Edit Offer")
            .font(.title)
            .padding()
    }
}
