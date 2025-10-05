import SwiftUI
import MapKit
import CoreLocation

struct UserRestaurantDetailView: View {
    let restaurant: Restaurant

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Int = 0

    @State private var dishes: [Dish] = []
    @State private var offers: [Offer] = []
    @State private var loadingMenu = true
    @State private var loadingOffers = true
    @State private var errorMenu: String?
    @State private var errorOffers: String?

    @State private var reviews: [Review] = []
    @State private var loadingReviews = true
    @State private var errorReviews: String?
    @State private var userNamesById: [String: String] = [:]

    private let usersRepo = UsersRepository()
    @State private var markingFavorite = false
    @State private var isFavorite = false
    @State private var favoriteError: String?

    private let visitsRepo = VisitsRepository()
    @State private var markingVisited = false
    @State private var hasVisited = false
    @State private var visitError: String?

    @State private var showPeople = false

    @State private var centerCoord: CLLocationCoordinate2D =
        CLLocationCoordinate2D(latitude: 4.6010, longitude: -74.0661)
    @State private var annotations: [MKPointAnnotation] = []

    private let dishesRepo = DishesRepository()
    private let offersRepo  = OffersRepository()
    private let reviewsRepo = ReviewsRepository()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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

                RestaurantSegmentedTab(selectedIndex: $selectedTab)
                    .frame(maxWidth: .infinity, alignment: .center)

                OSMMapView(
                    annotations: annotations,
                    center: centerCoord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01),
                    showsUserLocation: false
                )
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)

                HStack(spacing: 10) {
                    FilledActionButton(
                        title: "Favorite",
                        system: "heart.fill",
                        background: Palette.purple,
                        textColor: .white,
                        isEnabled: !isFavorite && !markingFavorite,
                        isLoading: markingFavorite && !isFavorite
                    ) { Task { await addToFavorites() } }

                    FilledActionButton(
                        title: "Remove as fav",
                        system: "heart.slash.fill",
                        background: Palette.grayLight,
                        textColor: Palette.burgundy,
                        isEnabled: isFavorite && !markingFavorite,
                        isLoading: markingFavorite && isFavorite
                    ) { Task { await removeFromFavorites() } }

                    FilledActionButton(
                        title: "People",
                        system: "bolt.horizontal.circle.fill",
                        background: Palette.purple
                    ) {
                        AnalyticsService.shared.log(EventName.peopleTapped, ["screen": ScreenName.restaurantDetail])
                        showPeople = true
                    }
                }
                .padding(.horizontal, 16)

                if let favoriteError {
                    Text(favoriteError)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .padding(.horizontal, 16)
                }

                InfoRowsView(
                    address: restaurant.address ?? "No address",
                    opening: restaurant.opening_time,
                    closing: restaurant.closing_time,
                    cuisine: restaurant.typeOfFood
                )
                .padding(.horizontal, 16)

                NavigationLink {
                    AddReviewView(restaurant: restaurant)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.pencil")
                        Text("Do a review")
                            .font(.custom("Montserrat-SemiBold", size: 16))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Palette.burgundy)
                    .clipShape(Capsule())
                    .shadow(radius: 2, y: 1)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    AnalyticsService.shared.log(EventName.reviewTap, [
                        "screen": ScreenName.restaurantDetail,
                        "restaurant_id": restaurant.id
                    ])
                })
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)
                .padding(.top, 6)

                Button {
                    Task { await markVisited() }
                } label: {
                    HStack(spacing: 8) {
                        if markingVisited {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Image(systemName: hasVisited ? "checkmark.circle.fill" : "mappin.and.ellipse")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        Text(hasVisited ? "Visited" : "Mark as visited")
                            .font(.custom("Montserrat-SemiBold", size: 16))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Palette.orange)
                    .clipShape(Capsule())
                    .shadow(radius: 2, y: 1)
                    .opacity(hasVisited || markingVisited ? 0.85 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(hasVisited || markingVisited)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)

                if let visitError {
                    Text(visitError)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 16)
                }

                Group {
                    switch selectedTab {
                    case 0:
                        MenuTab(dishes: dishes, loading: loadingMenu, error: errorMenu)
                    case 1:
                        OffersTab(offers: offers, loading: loadingOffers, error: errorOffers)
                    case 2:
                        ReviewsTab(reviews: reviews,
                                   loading: loadingReviews,
                                   error: errorReviews,
                                   userNamesById: userNamesById)
                    default:
                        MenuTab(dishes: dishes, loading: loadingMenu, error: errorMenu)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(isPresented: $showPeople) {
            PeopleNearbyView(restaurantName: restaurant.name)
        }
        .task { await initialLoad() }
        .onReceive(NotificationCenter.default.publisher(for: .userReviewsDidChange)) { _ in
            Task { await loadReviews() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .userFavoritesDidChange)) { _ in
            Task { await loadFavoriteState() }
        }
        .onAppear {
            AnalyticsService.shared.screenStart(ScreenName.restaurantDetail)
            AnalyticsService.shared.log(EventName.restaurantVisit, [
                "restaurant_id": restaurant.id,
                "restaurant_name": restaurant.name
            ])
        }
        .onDisappear {
            AnalyticsService.shared.screenEnd(ScreenName.restaurantDetail)
        }
    }
}

extension UserRestaurantDetailView {
    private func initialLoad() async {
        async let a: Void = prepareMapLocation()
        async let b: Void = loadMenu()
        async let c: Void = loadOffers()
        async let d: Void = loadFavoriteState()
        async let e: Void = loadReviews()
        async let f: Void = loadVisitedState()
        _ = await (a, b, c, d, e, f)
    }

    private func loadVisitedState() async {
        hasVisited = await visitsRepo.hasVisited(restaurantId: restaurant.id)
    }

    private func markVisited() async {
        guard !hasVisited else { return }
        markingVisited = true; visitError = nil
        defer { markingVisited = false }
        do {
            try await visitsRepo.markVisited(restaurantId: restaurant.id)
            hasVisited = true
            // ← Aquí estaba el error: ahora existe la constante.
            AnalyticsService.shared.log(EventName.restaurantMarkedVisited, ["restaurant_id": restaurant.id])
        } catch {
            visitError = error.localizedDescription
        }
    }

    private func loadFavoriteState() async {
        do { isFavorite = try await usersRepo.isFavorite(restaurantId: restaurant.id) }
        catch { favoriteError = error.localizedDescription }
    }

    private func addToFavorites() async {
        guard !isFavorite else { return }
        markingFavorite = true; favoriteError = nil
        defer { markingFavorite = false }
        do {
            try await usersRepo.addFavorite(restaurantId: restaurant.id)
            isFavorite = true
            AnalyticsService.shared.log(EventName.favoriteAdd, ["restaurant_id": restaurant.id])
        } catch {
            favoriteError = error.localizedDescription
        }
    }

    private func removeFromFavorites() async {
        guard isFavorite else { return }
        markingFavorite = true; favoriteError = nil
        defer { markingFavorite = false }
        do {
            try await usersRepo.removeFavorite(restaurantId: restaurant.id)
            isFavorite = false
            AnalyticsService.shared.log(EventName.favoriteRemove, ["restaurant_id": restaurant.id])
        } catch {
            favoriteError = error.localizedDescription
        }
    }

    private func loadMenu() async {
        loadingMenu = true; errorMenu = nil
        defer { loadingMenu = false }
        do { dishes = try await dishesRepo.listForRestaurant(uid: restaurant.id) }
        catch { errorMenu = error.localizedDescription }
    }

    private func loadOffers() async {
        loadingOffers = true; errorOffers = nil
        defer { loadingOffers = false }
        do { offers = try await offersRepo.listForRestaurant(uid: restaurant.id) }
        catch { errorOffers = error.localizedDescription }
    }

    private func loadReviews() async {
        loadingReviews = true; errorReviews = nil
        defer { loadingReviews = false }
        do {
            let list = try await reviewsRepo.listForRestaurant(restaurant.id)
            self.reviews = list
            let ids = Array(Set(list.map { $0.userId }))
            guard !ids.isEmpty else { self.userNamesById = [:]; return }
            let users = try await usersRepo.getManyBasic(ids: ids)
            var map: [String: String] = [:]
            for u in users { map[u.id] = u.name }
            self.userNamesById = map
        } catch {
            self.errorReviews = error.localizedDescription
        }
    }
}

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

private struct FilledActionButton: View {
    let title: String
    let system: String
    let background: Color
    var textColor: Color = .white
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: { if isEnabled && !isLoading { action() } }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .frame(height: 16)
                } else {
                    Image(systemName: system)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.custom("Montserrat-SemiBold", size: 13))
            }
            .foregroundColor(textColor)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .background(Capsule().fill(background))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 6)
            .opacity(isEnabled ? 1.0 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

private struct MenuTab: View {
    let dishes: [Dish]
    let loading: Bool
    let error: String?
    var body: some View {
        VStack(spacing: 12) {
            if loading { ProgressView().padding() }
            else if let error { Text(error).foregroundColor(.red) }
            else if dishes.isEmpty { Text("No dishes yet").foregroundColor(.secondary) }
            else {
                ForEach(dishes) { d in
                    UserRestaurantDishCard(
                        title: d.name, subtitle: d.description, imageURL: d.imageUrl, rating: d.rating
                    )
                }
            }
        }
    }
}

private struct OffersTab: View {
    let offers: [Offer]
    let loading: Bool
    let error: String?
    var body: some View {
        VStack(spacing: 12) {
            if loading { ProgressView().padding() }
            else if let error { Text(error).foregroundColor(.red) }
            else if offers.isEmpty { Text("No offers available").foregroundColor(.secondary) }
            else {
                ForEach(offers) { off in
                    OfferCard(title: off.title, description: off.description, imageURL: off.image, price: off.price)
                }
            }
        }
    }
}

private struct ReviewsTab: View {
    let reviews: [Review]
    let loading: Bool
    let error: String?
    let userNamesById: [String: String]

    var body: some View {
        VStack(spacing: 12) {
            if loading { ProgressView().padding() }
            else if let error { Text(error).foregroundColor(.red) }
            else if reviews.isEmpty { Text("No reviews yet").foregroundColor(.secondary) }
            else {
                ForEach(reviews) { r in
                    let author = userNamesById[r.userId] ?? "#\(r.userId.suffix(5))"
                    ReviewCard(
                        author: author,
                        restaurant: "—",
                        rating: r.stars,
                        comment: r.comment,
                        avatarURL: "",
                        reviewImageURL: r.imageURL
                    )
                }
            }
        }
    }
}
