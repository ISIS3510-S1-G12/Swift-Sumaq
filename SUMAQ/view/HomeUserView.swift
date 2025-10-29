import SwiftUI
import MapKit

/// PURPOSE:
/// Home screen showing search, banners, list of restaurants, and an embedded map backed by MapController.
///
/// STRATEGY OVERVIEW (used in this file):
/// - MARK: Strategy #3 (Swift Concurrency - async/await + MainActor): Asynchronous data loading with safe UI updates on the main actor.
/// - MARK: Strategy #4 (Structured Concurrency - TaskGroup): Used in MapController for per-restaurant processing; here we keep list loading simple.
/// UI safety: All @State mutations that impact rendering are performed on MainActor.

struct UserHomeView: View {
    var embedded: Bool = false

    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionHomeUserView? = nil
    @State private var selectedTab = 0
    @State private var restaurants: [Restaurant] = []
    @State private var loading = true
    @State private var error: String?

    @StateObject private var mapCtrl = MapController()
    private let repo = RestaurantsRepository()
    
    @State private var lastNewRestaurantVisit: Date?
    @State private var showNewRestaurantNotification = false
    private let visitsRepo = VisitsRepository()
    
    // Screen tracking
    @State private var screenStartTime: Date?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !embedded {
                    TopBar()
                    SegmentedTabs(selectedIndex: $selectedTab)
                        .onChange(of: selectedTab) { newValue in
                            let name: String
                            switch newValue {
                            case 0: name = "Home"
                            case 1: name = "Favorites"
                            case 2: name = "Offers"
                            case 3: name = "ReviewHistory"
                            default: name = "Unknown"
                            }
                            AnalyticsService.shared.log(EventName.tabSelect,
                                                        ["screen": ScreenName.home, "tab": name])
                        }
                }

                SearchFilterChatBar<FilterOptionHomeUserView>(
                    text: $searchText,
                    selectedFilter: $selectedFilter,
                    onChatTap: { },
                    config: .init(
                        searchColor: Palette.orange,
                        ringColor:   Palette.orange,
                        diameter:    44,
                        ringLineWidth: 2
                    )
                )
                .padding(.horizontal, 16)

                OSMMapView(
                    annotations: mapCtrl.annotations,
                    center: mapCtrl.center ?? CLLocationCoordinate2D(latitude: 4.6010, longitude: -74.0661),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01),
                    showsUserLocation: true
                )
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)

                // Mealtime banner
                MealTimeBanner(meal: MealTime.nowInColombia())
                    .padding(.horizontal, 16)
                
                if showNewRestaurantNotification {
                    let days = lastNewRestaurantVisit != nil ? daysSinceLastVisit(lastNewRestaurantVisit!) : 0
                    NewRestaurantNotification(daysSinceLastNewRestaurant: days)
                        .padding(.horizontal, 16)
                }

                if loading {
                    ProgressView().padding()
                } else if let error {
                    Text(error).foregroundColor(.red).padding(.horizontal, 16)
                } else if filtered.isEmpty {
                    Text("No restaurants found").foregroundColor(.secondary).padding()
                } else {
                    VStack(spacing: 14) {
                        ForEach(filtered, id: \.id) { r in
                            NavigationLink {
                                UserRestaurantDetailView(restaurant: r)
                            } label: {
                                RestaurantCard(
                                    name: r.name,
                                    category: r.typeOfFood.isEmpty ? "Restaurant" : "\(r.typeOfFood) restaurant",
                                    tag: r.offer ? "Offers" : "",
                                    rating: r.rating,
                                    imageURL: r.imageUrl ?? "",
                                    panelColor: Palette.purpleLight
                                )
                            }
                            .buttonStyle(.plain)
                            .simultaneousGesture(TapGesture().onEnded {
                                AnalyticsService.shared.log(EventName.restaurantOpen, [
                                    "source": "home_list",
                                    "restaurant_id": r.id,
                                    "restaurant_name": r.name
                                ])
                            })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, embedded ? 0 : 8)
        }
        .onAppear {
            screenStartTime = Date()
            SessionTracker.shared.trackScreenView(ScreenName.home, category: ScreenCategory.mainNavigation)
            AnalyticsService.shared.screenStart(ScreenName.home)
            LocationPermissionLogger.shared.startObserving()
        }
        .onDisappear {
            if let startTime = screenStartTime {
                let duration = Date().timeIntervalSince(startTime)
                SessionTracker.shared.trackScreenEnd(ScreenName.home, duration: duration, category: ScreenCategory.mainNavigation)
            }
            AnalyticsService.shared.screenEnd(ScreenName.home)
        }
        // MARK: Strategy #3 — Swift Concurrency (async/await)
        // Kick off concurrent work without blocking UI.
        .task { await mapCtrl.loadRestaurants() }
        .task { await loadRestaurants() }
        .task { await loadNewRestaurantNotification() }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private var filtered: [Restaurant] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return restaurants }
        // Simple in-memory filter; for huge datasets consider off-main processing.
        return restaurants.filter { r in
            r.name.lowercased().contains(q)
            || r.typeOfFood.lowercased().contains(q)
            || (r.address ?? "").lowercased().contains(q)
        }
    }

    // MARK: Strategy #3 — Simple async load; publish on MainActor
    private func loadRestaurants() async {
        await MainActor.run {
            loading = true
            error = nil
        }
        
        do {
            // Single throwing async fetch; no TaskGroup needed here.
            let fetched = try await repo.all()
            await MainActor.run {
                self.restaurants = fetched
                self.loading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.loading = false
            }
        }
    }
    
    // MARK: Strategy #3 — Async load and UI update on MainActor
    private func loadNewRestaurantNotification() async {
        let visitDate = await visitsRepo.getLastNewRestaurantVisit()
        
        await MainActor.run {
            self.lastNewRestaurantVisit = visitDate
            if let lastVisit = visitDate {
                let daysSince = daysSinceLastVisit(lastVisit)
                self.showNewRestaurantNotification = daysSince > 3
            } else {
                self.showNewRestaurantNotification = true
            }
        }
    }
    
    private func daysSinceLastVisit(_ date: Date) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.startOfDay(for: now)
        let components = calendar.dateComponents([.day], from: startOfDay, to: endOfDay)
        return components.day ?? 0
    }
}

#Preview { UserHomeView() }

// Supporting UI components (unchanged behavior)

private enum MealTime {
    case breakfast, lunch, dinner, other

    static func nowInColombia(date: Date = Date()) -> MealTime {
        let tz = TimeZone(identifier: "America/Bogota") ?? .current
        var cal = Calendar.current
        cal.timeZone = tz
        let hour = cal.component(.hour, from: date)

        // Colombia time windows:
        // Breakfast: 5:00–10:59, Lunch: 11:00–15:59, Dinner: 18:00–22:59
        switch hour {
        case 5...10:   return .breakfast
        case 11...15:  return .lunch
        case 18...22:  return .dinner
        default:       return .other
        }
    }

    var title: String {
        switch self {
        case .breakfast: return "Breakfast time"
        case .lunch:     return "Lunch time"
        case .dinner:    return "Dinner time"
        case .other:     return "Feeling hungry?"
        }
    }

    var message: String {
        switch self {
        case .breakfast: return "Start your day with energy."
        case .lunch:     return "Recharge with something delicious."
        case .dinner:    return "Treat yourself tonight."
        case .other:     return "Discover great places nearby."
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "cup.and.saucer.fill"
        case .lunch:     return "fork.knife"
        case .dinner:    return "moon.stars.fill"
        case .other:     return "leaf.fill"
        }
    }
}

private struct MealTimeBanner: View {
    let meal: MealTime

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: meal.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.title)
                    .font(.custom("Montserrat-SemiBold", size: 16))
                    .foregroundColor(.white)
                Text(meal.message)
                    .font(.custom("Montserrat-Regular", size: 13))
                    .foregroundColor(.white.opacity(0.95))
            }
            Spacer()
        }
        .padding(14)
        .background(Palette.purple)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 6)
    }
}

private struct NewRestaurantNotification: View {
    let daysSinceLastNewRestaurant: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("It's time to try a new restaurant!")
                    .font(.custom("Montserrat-SemiBold", size: 16))
                    .foregroundColor(.white)
                Text("\(daysSinceLastNewRestaurant) days have passed since you tried a new restaurant")
                    .font(.custom("Montserrat-Regular", size: 13))
                    .foregroundColor(.white.opacity(0.95))
            }
            Spacer()
        }
        .padding(14)
        .background(Palette.orange)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 6)
    }
}
