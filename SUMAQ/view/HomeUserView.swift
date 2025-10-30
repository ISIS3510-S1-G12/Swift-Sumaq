//
//  HomeUserView.swift
//  SUMAQ
//
//  Multithreading - STRATEGY #4 Task Group Maria
//  --------------------------------------------------
// Home screen more responsive by orchestrating all initial fetches in
//  parallel using Swift Structured Concurrency (Task Group).

//   - Use `withTaskGroup(of: Void.self)` to start concurrent child tasks for:
//       (1) loading restaurants (cards),
//       (2) loading the "new restaurant" notification state,
//       (3) initializing the map via MapController.
//   - Store results in local variables inside the group and apply them to @State
//     once all tasks have completed; this is the point where the loading indicator is hidden.
//   - This preserves the public API and UI layout while making the first render reactive and efficient.
//

import SwiftUI
import MapKit

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
        // Structured Concurrency orchestration entry point:
        // Run all initial fetches in parallel and commit state once they're all done.
        .task { await initializeScreenConcurrently() }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    // MARK: - Derived filtering
    private var filtered: [Restaurant] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return restaurants }
        return restaurants.filter { r in
            r.name.lowercased().contains(q)
            || r.typeOfFood.lowercased().contains(q)
            || (r.address ?? "").lowercased().contains(q)
        }
    }

    // MARK: - Structured Concurrency Orchestration
    /// Orchestrates the initial content loading using Task Group.
    private func initializeScreenConcurrently() async {
        // Show loading and clear prior error at kickoff.
        await MainActor.run {
            loading = true
            error = nil
        }

        // Local result holders to be committed after the group finishes.
        var tmpRestaurants: [Restaurant] = []
        var tmpError: String?
        var tmpLastVisit: Date?
        var tmpShowNotification = false

        await withTaskGroup(of: Void.self) { group in
            // Task 1 — Restaurants (Cards)
            group.addTask {
                do {
                    let list = try await repo.all()
                    await MainActor.run { tmpRestaurants = list }
                } catch {
                    await MainActor.run { tmpError = error.localizedDescription }
                }
            }

            // Task 2 — Map initial state (delegates to controller; it updates its own @Published)
            group.addTask {
                await mapCtrl.loadRestaurants()
            }

            // Task 3 — New restaurant notification
            group.addTask {
                let last = await visitsRepo.getLastNewRestaurantVisit()
                let show: Bool
                if let last {
                    show = daysSinceLastVisit(last) > 3
                } else {
                    show = true
                }
                await MainActor.run {
                    tmpLastVisit = last
                    tmpShowNotification = show
                }
            }
        }

        // Commit all results to the view state once all tasks have completed.
        await MainActor.run {
            if let tmpError {
                error = tmpError
            } else {
                restaurants = tmpRestaurants
            }
            lastNewRestaurantVisit = tmpLastVisit
            showNewRestaurantNotification = tmpShowNotification
            loading = false
        }
    }

    // MARK: - Legacy single-purpose loaders (kept for compatibility; no longer used by `.task`)
    // These functions are intentionally preserved to avoid changing public surface or other call sites.
    private func loadRestaurants() async {
        loading = true; error = nil
        do { restaurants = try await repo.all() }
        catch { self.error = error.localizedDescription }
        loading = false
    }
    
    private func loadNewRestaurantNotification() async {
        lastNewRestaurantVisit = await visitsRepo.getLastNewRestaurantVisit()
        if let lastVisit = lastNewRestaurantVisit {
            let daysSince = daysSinceLastVisit(lastVisit)
            showNewRestaurantNotification = daysSince > 3
        } else {
            showNewRestaurantNotification = true
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

private enum MealTime {
    case breakfast, lunch, dinner, other

    static func nowInColombia(date: Date = Date()) -> MealTime {
        let tz = TimeZone(identifier: "America/Bogota") ?? .current
        var cal = Calendar.current
        cal.timeZone = tz
        let hour = cal.component(.hour, from: date)

        // Colombia ranges:
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
