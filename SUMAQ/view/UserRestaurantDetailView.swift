import SwiftUI
import MapKit
import CoreLocation

struct UserRestaurantDetailView: View {
    let restaurant: Restaurant

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: Int = 0
    @State private var screenStartTime: Date?

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
    @State private var userAvatarsById: [String: String] = [:]
    
    // Network connectivity for reviews
    @State private var hasInternetConnectionReviews = true
    
    // Navigation and alert states for "Do a review"
    @State private var showAddReview = false
    @State private var showOfflineAlert = false

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


                if selectedTab == 0 {
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
                }

                if selectedTab == 2 {
                    HStack {
                        Button {
                            // Check internet connection before navigating
                            if NetworkHelper.shared.isConnectedToNetwork() {
                                showAddReview = true
                                AnalyticsService.shared.log(EventName.reviewTap, [
                                    "screen": ScreenName.restaurantDetail,
                                    "restaurant_id": restaurant.id
                                ])
                            } else {
                                showOfflineAlert = true
                            }
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
                        NavigationLink(destination: AddReviewView(restaurant: restaurant),
                                     isActive: $showAddReview) {
                            EmptyView()
                        }
                        .hidden()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .alert("No internet connection", isPresented: $showOfflineAlert) {
                        Button("OK", role: .cancel) { }
                    } message: {
                        Text("We know your opinion is important, but please try again when you have an internet connection. Reviews need to be uploaded to be saved.")
                    }
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
                                   userNamesById: userNamesById,
                                   userAvatarsById: userAvatarsById,
                                   hasInternetConnection: hasInternetConnectionReviews)
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
            // Check internet connection for reviews
            checkInternetConnectionReviews()
            screenStartTime = Date()
            AnalyticsService.shared.screenStart(ScreenName.restaurantDetail)
            AnalyticsService.shared.log(EventName.restaurantVisit, [
                "restaurant_id": restaurant.id,
                "restaurant_name": restaurant.name
            ])
        }
        .onDisappear {
            if let startTime = screenStartTime {
                let duration = Date().timeIntervalSince(startTime)
                AnalyticsService.shared.screenEnd(ScreenName.restaurantDetail)
            }
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
            // Use GCD to parallelize independent operations
            let group = DispatchGroup()
            var reviewsResult: [Review] = []
            var usersResult: [AppUser] = []
            var reviewsError: Error?
            var usersError: Error?
            
            // Load reviews on background queue
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                Task {
                    do {
                        reviewsResult = try await self.reviewsRepo.listForRestaurant(self.restaurant.id)
                    } catch {
                        reviewsError = error
                    }
                    group.leave()
                }
            }
            
            // Wait asynchronously for the group to finish
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                group.notify(queue: .global(qos: .userInitiated)) { cont.resume() }
            }
            
            // Check for reviews error first
            if let error = reviewsError {
                throw error
            }
            
            self.reviews = reviewsResult
            let userIds = Array(Set(reviewsResult.map { $0.userId }))
            
            // Load user data in parallel if we have user IDs
            if !userIds.isEmpty {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    Task {
                        do {
                            usersResult = try await self.usersRepo.getManyBasic(ids: userIds)
                        } catch {
                            usersError = error
                        }
                        group.leave()
                    }
                }
                // Wait asynchronously for the group to finish
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    group.notify(queue: .global(qos: .userInitiated)) { cont.resume() }
                }
                
                if let error = usersError {
                    throw error
                }
                
                var names: [String: String] = [:]
                var avatars: [String: String] = [:]
                for u in usersResult {
                    names[u.id] = u.name
                    if let url = u.profilePictureURL, !url.isEmpty { avatars[u.id] = url }
                }
                self.userNamesById = names
                self.userAvatarsById = avatars
            } else {
                self.userNamesById = [:]
                self.userAvatarsById = [:]
            }
        } catch {
            self.errorReviews = error.localizedDescription
        }
    }
    
    // MARK: - Network Connectivity for Reviews
    private func checkInternetConnectionReviews() {
        // Use simple synchronous check for immediate UI update
        hasInternetConnectionReviews = NetworkHelper.shared.isConnectedToNetwork()
        
        // Also use async check for more accurate result
        NetworkHelper.shared.checkNetworkConnection { isConnected in
            Task { @MainActor in
                self.hasInternetConnectionReviews = isConnected
            }
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
    let userAvatarsById: [String: String]
    let hasInternetConnection: Bool

    var body: some View {
        VStack(spacing: 12) {
            if loading {
                ProgressView().padding()
                Text("Loading Reviews…")
                    .font(.custom("Montserrat-Regular", size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("If you are having a slow connection or if you are offline, we will show you the saved reviews in a moment.")
                    .font(.custom("Montserrat-Regular", size: 12))
                    .foregroundStyle(.secondary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else if let error {
                VStack(spacing: 12) {
                    if !hasInternetConnection {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("No internet connection")
                            .font(.custom("Montserrat-SemiBold", size: 16))
                            .foregroundStyle(.primary)
                        Text("We couldn't load the reviews. Please check your internet connection and try again.")
                            .font(.custom("Montserrat-Regular", size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    } else {
                        Text(error)
                            .font(.custom("Montserrat-Regular", size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.vertical, 16)
            } else if reviews.isEmpty {
                Text("No reviews yet").foregroundColor(.secondary)
            } else {
                ForEach(reviews) { r in
                    let author = userNamesById[r.userId] ?? "#\(r.userId.suffix(5))"
                    let avatar = userAvatarsById[r.userId] ?? ""
                    ReviewCard(
                        author: author,
                        restaurant: "—",
                        rating: r.stars,
                        comment: r.comment,
                        avatarURL: avatar,
                        reviewImageURL: r.imageURL,
                        reviewLocalPath: r.imageLocalPath
                    )
                }
            }
        }
    }
}
