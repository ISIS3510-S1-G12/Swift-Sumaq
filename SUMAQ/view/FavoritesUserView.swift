//
//  FavoritesUserView.swift
//  SUMAQ
//

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

    private let usersRepo = UsersRepository()
    private let restaurantsRepo = RestaurantsRepository()

    @ObservedObject private var session = SessionController.shared

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

                if loading {
                    ProgressView().padding()
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
        .background(Color(.systemBackground).ignoresSafeArea())
        // Cargar al entrar
        .task { await loadFavorites() }
        // Refrescar cuando se cambien favoritos o cambie la sesión
        .onReceive(NotificationCenter.default.publisher(for: .userFavoritesDidChange)) { _ in
            Task { await loadFavorites() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .authStateDidChange)) { _ in
            Task { await loadFavorites() }
        }
    }

    // MARK: Helpers
    private var filtered: [Restaurant] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return restaurants }
        return restaurants.filter { r in
            r.name.lowercased().contains(q)
            || r.typeOfFood.lowercased().contains(q)
            || (r.address ?? "").lowercased().contains(q)
        }
    }

    private func loadFavorites() async {
        loading = true; error = nil
        do {
            // Si no es un "user" logeado, muestra vacío
            guard session.isAuthenticated, session.role == .user else {
                favoriteIds = []; restaurants = []; loading = false; return
            }
            favoriteIds = try await usersRepo.listFavoriteRestaurantIds()
            restaurants = try await restaurantsRepo.getMany(ids: favoriteIds)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
