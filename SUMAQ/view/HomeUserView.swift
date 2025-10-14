import SwiftUI
import MapKit

struct UserHomeView: View {
    var embedded: Bool = false

    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionHomeUserView? = nil
    @State private var selectedTab = 0

    // Data
    @State private var restaurants: [Restaurant] = []
    @State private var loading = true
    @State private var error: String?

    @StateObject private var mapCtrl = MapController()
    private let repo = RestaurantsRepository()
    
    // New restaurant notification
    @State private var lastNewRestaurantVisit: Date?
    @State private var showNewRestaurantNotification = false
    private let visitsRepo = VisitsRepository()

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

                // Banner dinámico por mealtime (Colombia)
                MealTimeBanner(meal: MealTime.nowInColombia())
                    .padding(.horizontal, 16)
                
                // Notificación de nuevo restaurante
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
            AnalyticsService.shared.screenStart(ScreenName.home)
            LocationPermissionLogger.shared.startObserving()
        }
        .onDisappear {
            AnalyticsService.shared.screenEnd(ScreenName.home)
        }
        .task { await mapCtrl.loadRestaurants() }
        .task { await loadRestaurants() }
        .task { await loadNewRestaurantNotification() }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    private var filtered: [Restaurant] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return restaurants }
        return restaurants.filter { r in
            r.name.lowercased().contains(q)
            || r.typeOfFood.lowercased().contains(q)
            || (r.address ?? "").lowercased().contains(q)
        }
    }

    private func loadRestaurants() async {
        loading = true; error = nil
        do { restaurants = try await repo.all() }
        catch { self.error = error.localizedDescription }
        loading = false
    }
    
    private func loadNewRestaurantNotification() async {
        lastNewRestaurantVisit = await visitsRepo.getLastNewRestaurantVisit()
        
        // Solo mostrar la notificación si han pasado más de 7 días desde la última visita a un restaurante nuevo
        // Si nunca ha visitado un restaurante nuevo, también mostrar la notificación
        if let lastVisit = lastNewRestaurantVisit {
            let daysSince = daysSinceLastVisit(lastVisit)
            showNewRestaurantNotification = daysSince > 7  // Más de 7 días (no incluye el día 7)
        } else {
            // Si nunca ha visitado un restaurante nuevo, mostrar la notificación
            showNewRestaurantNotification = true
        }
    }
    
    private func daysSinceLastVisit(_ date: Date) -> Int {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: date, to: now)
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

        // Franja típica en Colombia:
        // Desayuno: 5:00–10:59, Almuerzo: 11:00–15:59, Cena: 18:00–22:59
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
