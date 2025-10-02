//
//  UserRestaurantDetailView.swift
//  SUMAQ
//

import SwiftUI
import MapKit
import CoreLocation

struct UserRestaurantDetailView: View {
    let restaurant: Restaurant

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Int = 0

    // Data
    @State private var dishes: [Dish] = []
    @State private var offers: [Offer] = []
    @State private var loadingMenu = true
    @State private var loadingOffers = true
    @State private var errorMenu: String?
    @State private var errorOffers: String?

    // Favoritos
    private let usersRepo = UsersRepository()
    @State private var markingFavorite = false
    @State private var isFavorite = false
    @State private var favoriteError: String?

    // Mapa / ubicación puntual
    @State private var centerCoord: CLLocationCoordinate2D =
        CLLocationCoordinate2D(latitude: 4.6010, longitude: -74.0661)
    @State private var annotations: [MKPointAnnotation] = []

    // Repos
    private let dishesRepo = DishesRepository()
    private let offersRepo  = OffersRepository()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Encabezado: buttom de back + nombre
                HStack(spacing: 8) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Palette.burgundy)
                    }
                    Text(restaurant.name)
                        .font(.custom("Montserrat-SemiBold", size: 22))
                        .foregroundColor(Palette.burgundy)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Tabs
                RestaurantSegmentedTab(selectedIndex: $selectedTab)
                    .frame(maxWidth: .infinity, alignment: .center)

                // Mapa con un pin del restaurante
                OSMMapView(
                    annotations: annotations,
                    center: centerCoord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01),
                    showsUserLocation: false
                )
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)

                // Pills de acciones
                HStack(spacing: 10) {
                    ActionPill(
                        title: isFavorite ? "Favorited" : "Mark as favorite",
                        system: isFavorite ? "heart.circle.fill" : "heart.fill",
                        color: Palette.purple
                    ) {
                        Task { await markFavorite() }
                    }
                    .opacity(markingFavorite ? 0.6 : 1)
                    .disabled(markingFavorite)

                    ActionPill(title: "Do a review",
                               system: "square.and.pencil",
                               color: Palette.burgundy) { }

                    ActionPill(title: "People",
                               system: "bolt.horizontal.circle",
                               color: Palette.purple) { }
                }
                .padding(.horizontal, 16)

                if let favoriteError {
                    Text(favoriteError)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal, 16)
                }

                // Info del restaurante
                InfoRowsView(
                    address: restaurant.address ?? "No address",
                    opening: restaurant.opening_time,
                    closing: restaurant.closing_time,
                    cuisine: restaurant.typeOfFood
                )
                .padding(.horizontal, 16)

                // Contenido por tab
                Group {
                    switch selectedTab {
                    case 0:
                        MenuTab(dishes: dishes,
                                loading: loadingMenu,
                                error: errorMenu)
                    case 1:
                        OffersTab(offers: offers,
                                  loading: loadingOffers,
                                  error: errorOffers)
                    case 2:
                        ReviewsTab()
                    default:
                        MenuTab(dishes: dishes,
                                loading: loadingMenu,
                                error: errorMenu)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemBackground).ignoresSafeArea())

        // Cargas iniciales
        .task { await prepareMapLocation() }
        .task { await loadMenu() }
        .task { await loadOffers() }
        .task { await loadFavoriteState() }
    }
}

// MARK: - Acciones / Datos
extension UserRestaurantDetailView {
    private func loadMenu() async {
        loadingMenu = true; errorMenu = nil
        do { dishes = try await dishesRepo.listForRestaurant(uid: restaurant.id) }
        catch { errorMenu = error.localizedDescription }
        loadingMenu = false
    }

    private func loadOffers() async {
        loadingOffers = true; errorOffers = nil
        do { offers = try await offersRepo.listForRestaurant(uid: restaurant.id) }
        catch { errorOffers = error.localizedDescription }
        loadingOffers = false
    }

    private func loadFavoriteState() async {
        do { isFavorite = try await usersRepo.isFavorite(restaurantId: restaurant.id) }
        catch { favoriteError = error.localizedDescription }
    }

    private func markFavorite() async {
        guard !isFavorite else { return }  // ya marcado
        markingFavorite = true; favoriteError = nil
        do {
            try await usersRepo.addFavorite(restaurantId: restaurant.id)
            isFavorite = true
        } catch {
            favoriteError = error.localizedDescription
        }
        markingFavorite = false
    }
}

// MARK: - Mapa
extension UserRestaurantDetailView {
    private func prepareMapLocation() async {
        if let la = restaurant.lat, let lo = restaurant.lon {
            updateMap(lat: la, lon: lo); return
        }
        if let addr = restaurant.address, !addr.isEmpty {
            await geocodeAddress(addr)
        }
    }

    private func updateMap(lat: Double, lon: Double) {
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        centerCoord = coord

        let pin = MKPointAnnotation()
        pin.title = restaurant.name
        pin.coordinate = coord
        annotations = [pin]
    }

    private func geocodeAddress(_ address: String) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            CLGeocoder().geocodeAddressString(address) { placemarks, _ in
                if let loc = placemarks?.first?.location {
                    updateMap(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
                }
                cont.resume()
            }
        }
    }
}

// MARK: - Subvistas
private struct InfoRowsView: View {
    let address: String
    let opening: Int?
    let closing: Int?
    let cuisine: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            InfoRow(icon: "mappin.and.ellipse", text: address)
            if let opening, let closing {
                InfoRow(icon: "clock",
                        text: "\(format(hhmm: opening)) – \(format(hhmm: closing))")
            }
            if !cuisine.isEmpty {
                InfoRow(icon: "fork.knife", text: cuisine)
            }
        }
    }

    private func format(hhmm: Int) -> String {
        let h = hhmm / 100
        let m = hhmm % 100
        return String(format: "%02d:%02d", h, m)
    }
}

private struct InfoRow: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Palette.purple)
                .frame(width: 20)
            Text(text)
                .font(.custom("Montserrat-Regular", size: 14))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ActionPill: View {
    let title: String
    let system: String
    let color: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: system)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(.custom("Montserrat-SemiBold", size: 13))
            }
            .foregroundColor(color)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(Color.white)
                    .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// Tab Menú (usuario, morado)
private struct MenuTab: View {
    let dishes: [Dish]
    let loading: Bool
    let error: String?

    var body: some View {
        VStack(spacing: 12) {
            if loading {
                ProgressView().padding()
            } else if let error {
                Text(error).foregroundColor(.red)
            } else if dishes.isEmpty {
                Text("No dishes yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(dishes) { d in
                    UserRestaurantDishCard(
                        title: d.name,
                        subtitle: d.description,
                        imageURL: d.imageUrl,
                        rating: d.rating
                    )
                }
            }
        }
    }
}

// Tab Offers (reutiliza OfferCard)
private struct OffersTab: View {
    let offers: [Offer]
    let loading: Bool
    let error: String?

    var body: some View {
        VStack(spacing: 12) {
            if loading {
                ProgressView().padding()
            } else if let error {
                Text(error).foregroundColor(.red)
            } else if offers.isEmpty {
                Text("No offers available")
                    .foregroundColor(.secondary)
            } else {
                ForEach(offers) { off in
                    OfferCard(
                        title: off.title,
                        description: off.description,
                        imageURL: off.image
                    )
                }
            }
        }
    }
}

// Tab Reviews — placeholder
private struct ReviewsTab: View {
    var body: some View {
        VStack(spacing: 12) {
            ReviewCard(author: "User123", restaurant: "—", rating: 5, comment: "Great place!")
            ReviewCard(author: "Foodie", restaurant: "—", rating: 4, comment: "Nice service and tasty dishes.")
        }
    }
}
