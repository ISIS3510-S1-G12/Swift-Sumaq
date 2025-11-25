// FavoritesUserView.swift
// SUMAQ

import SwiftUI

struct FavoritesUserView: View {
    var embedded: Bool = false

    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionFavoritesView? = nil
    @State private var selectedTab = 1

    @State private var favoriteIds: [String] = []
    @State private var restaurants: [Restaurant] = []
    @State private var loading = true
    @State private var error: String?

    @State private var stats: FavoritesStats = .init(total: 0, withOffers: 0, percentWithOffers: 0, restaurantsWithOffers: [])

    private let usersRepo = UsersRepository()
    private let restaurantsRepo = RestaurantsRepository()

    @ObservedObject private var session = SessionController.shared

    @State private var loadTask: Task<Void, Never>?
    @State private var isLoadingData = false
    
    // Screen tracking
    @State private var screenStartTime: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !embedded {
                    TopBar()
                    SegmentedTabs(selectedIndex: $selectedTab)
                    Rectangle().fill(Palette.burgundy).frame(height: 1).padding(.horizontal, 16)
                }

                SearchFilterChatBar<FilterOptionFavoritesView>(
                    text: $searchText,
                    selectedFilter: $selectedFilter,
                    onChatTap: { },
                    config: .init(searchColor: Palette.orange, ringColor: Palette.orange)
                )
                .padding(.horizontal, 16)

                FavoritesStatsCard(stats: stats)
                    .padding(.horizontal, 16)
                    .accessibilityIdentifier("favorites_stats_card")

                if loading {
                    ProgressView().padding()
                    Text("Loading your Favorites…")
                    .font(.custom("Montserrat-Regular", size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    Text("If you are having a slow connection or if you are offline, we will show you your saved favorites in a moment.")
                    .font(.custom("Montserrat-Regular", size: 12))
                    .foregroundStyle(.secondary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                } else if let error {
                    Text(error).foregroundColor(.red).padding(.horizontal, 16)
                } else if filtered.isEmpty {
                    Text("No favorites yet").foregroundColor(.secondary).padding()
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
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, embedded ? 0 : 8)
        }
        .navigationBarBackButtonHidden(true)
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            screenStartTime = Date()
            SessionTracker.shared.trackScreenView(ScreenName.favorites, category: ScreenCategory.mainNavigation)
        }
        .onDisappear {
            if let startTime = screenStartTime {
                let duration = Date().timeIntervalSince(startTime)
                SessionTracker.shared.trackScreenEnd(ScreenName.favorites, duration: duration, category: ScreenCategory.mainNavigation)
            }
        }
        .task {
            guard !isLoadingData else { return }
            await safeLoadFavorites()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userFavoritesDidChange)) { _ in
            loadTask?.cancel()
            guard !isLoadingData else { return }
            loadTask = Task { await safeLoadFavorites() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
            loadTask?.cancel()
            guard !isLoadingData else { return }
            loadTask = Task { await safeLoadFavorites() }
        }
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

    private func safeLoadFavorites() async {
        // Prevent multiple simultaneous loads
        guard !isLoadingData else { return }
        isLoadingData = true
        
        loading = true; error = nil
        defer { 
            loading = false
            isLoadingData = false
        }
        do {
            // Check for cancellation before proceeding
            try Task.checkCancellation()
            
            guard session.isAuthenticated, session.role == .user else {
                favoriteIds = []; restaurants = []; stats = FavoritesInsight.makeStats(from: [])
                return
            }
            favoriteIds = try await usersRepo.listFavoriteRestaurantIds()
            if favoriteIds.isEmpty {
                restaurants = []
                stats = FavoritesInsight.makeStats(from: restaurants)
                AnalyticsService.shared.log("favorites_stats", [
                    "total": stats.total,
                    "with_offers": stats.withOffers,
                    "percent": stats.percentWithOffers
                ])
                return
            }
            restaurants = try await restaurantsRepo.getMany(ids: favoriteIds)
            stats = FavoritesInsight.makeStats(from: restaurants)
            AnalyticsService.shared.log("favorites_stats", [
                "total": stats.total,
                "with_offers": stats.withOffers,
                "percent": stats.percentWithOffers
            ])
        } catch {
            if Task.isCancelled { return }
            self.error = error.localizedDescription
        }
    }
}


private struct FavoritesStatsCard: View {
    let stats: FavoritesStats
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Favorites notifications", systemImage: "bell.badge")
                    .font(.custom("Montserrat-SemiBold", size: 16))
                    .foregroundStyle(Palette.burgundy)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Palette.purple)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                StatPill(title: "Total", value: "\(stats.total)")
                StatPill(title: "With offers", value: "\(stats.withOffers)")
                StatPill(title: "% offers", value: "\(stats.percentWithOffers)%")
            }

            if expanded {
                Divider().padding(.vertical, 4)
                if stats.restaurantsWithOffers.isEmpty {
                    Text("No favorite with an active offer today.")
                        .font(.custom("Montserrat-Regular", size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Restaurants with offers today")
                            .font(.custom("Montserrat-SemiBold", size: 14))
                            .foregroundStyle(Palette.purple)
                        ForEach(stats.restaurantsWithOffers, id: \.self) { name in
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Palette.purple)
                                Text(name)
                                    .font(.custom("Montserrat-Regular", size: 13))
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.grayLight)
        )
    }
}

private struct StatPill: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Palette.purple)
            Text(title)
                .font(.custom("Montserrat-Regular", size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        )
    }
}

//SPRINT 3- Multithreading- Swift Concurrency (async/wait)
//Patrón usado: Swift Concurrency async/await con Task ligado al ciclo de vida de la vista.
//Multithreading real: el runtime usa un thread pool cooperativo; await suspende sin bloquear, el trabajo de red va en background; tras await, la lógica de UI vuelve al MainActor.
//Cancelación: en cambios de sesión o favoritos, se cancela la tarea anterior para evitar condiciones de carrera y estados inconsistentes.
// sucede cuando se crea el contexto asíncrono : .task { await safeLoadFavorites() }
// en la definicion de safeLoadFavorites se pone async
// se guarda el Task actual en loadTask y se cancela si llega un evento que invalida el resultado (cambió auth o favoritos), evitando pisadas de estado
