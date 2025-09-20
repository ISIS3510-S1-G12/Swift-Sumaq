//
//  RestaurantHomeView.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDOÑO on 20/09/25.
//

import Foundation
import SwiftUI
import MapKit


enum RestaurantHomeRoute: Hashable {
    case offers
}

struct RestaurantHomeView: View {
    @State private var selectedTab: Int = 0           // Menú por defecto
    @State private var searchText: String = ""
    @State private var navPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    RestaurantTopBar(restaurantLogo: "AppLogoUI", appLogo: "AppLogoUI")

                    Text("Lucille")
                        .font(.custom("Montserrat-SemiBold", size: 22))
                        .foregroundColor(Palette.burgundy)
                        .padding(.horizontal, 16)

                   
                    RestaurantSegmentedTab(selectedIndex: $selectedTab) { idx in
                        switch idx {
                        case 1:
                            navPath.append(RestaurantHomeRoute.offers)
                        default:
                            break
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    // Mapa OSM
                    OSMMapView(
                        center: CLLocationCoordinate2D(latitude: 4.6010, longitude: -74.0661),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)

                    // Busiest Hours
                    HStack {
                        Spacer()
                        Button { } label: {
                            HStack(spacing: 8) {
                                Text("Busiest Hours")
                                    .font(.custom("Montserrat-SemiBold", size: 14))
                                Image(systemName: "chart.bar.fill")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Palette.teal)
                            .clipShape(Capsule())
                        }
                        Spacer()
                    }

                    // Cards
                    VStack(spacing: 12) {
                        RestaurantDishCard(
                            title: "Bacon Sandwich",
                            subtitle: "Hamburger with a lot of bacon.",
                            imageName: "Dish1",
                            rating: 4
                        )

                        RestaurantDishCard(
                            title: "BBQ Sandwich",
                            subtitle: "Hamburger with a lot of BBQ.",
                            imageName: "Dish2",
                            rating: 4
                        )
                    }
                    .padding(.horizontal, 16)

                    // Botones inferiores
                    HStack(spacing: 12) {
                        NavigationLink {
                            NewMenuView()
                        } label: {
                            SmallCapsuleButton(title: "New Menu",
                                               background: Palette.orangeAlt,
                                               textColor: .white)
                        }

                        NavigationLink {
                            EditMenuView()
                        } label: {
                            SmallCapsuleButton(title: "Edit Menu",
                                               background: Color.gray.opacity(0.6),
                                               textColor: .white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .padding(.top, 8)
            }
            .background(Color.white.ignoresSafeArea())
            // Destinos de navegación
            .navigationDestination(for: RestaurantHomeRoute.self) { route in
                switch route {
                case .offers:
                        RestaurantOffersView()
                    default:
                        RestaurantOffersView()
        
                }
            }
        }
    }
}

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

struct NewMenuView: View {
    var body: some View {
        Text("New Menu")
            .font(.title)
            .padding()
    }
}

struct EditMenuView: View {
    var body: some View {
        Text("Edit Menu")
            .font(.title)
            .padding()
    }
}
