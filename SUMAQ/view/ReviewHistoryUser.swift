import SwiftUI

struct ReviewHistoryUserView: View {
    var embedded: Bool = false

    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionReviewHistoryView? = nil
    @State private var selectedTab = 3

    // Datos
    @State private var loading = true
    @State private var error: String?
    @State private var reviews: [Review] = []
    @State private var userName: String = "You"
    @State private var restaurantsById: [String: Restaurant] = [:]

    private let reviewsRepo = ReviewsRepository()
    private let usersRepo = UsersRepository()
    private let restaurantsRepo = RestaurantsRepository()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !embedded {
                    TopBar()
                    SegmentedTabs(selectedIndex: $selectedTab)
                }

                FilterBar<FilterOptionReviewHistoryView>(
                    text: $searchText,
                    selectedFilter: $selectedFilter
                )
                .padding(.horizontal, 16)

                if loading {
                    ProgressView().padding()
                } else if let error {
                    Text(error).foregroundColor(.red).padding(.horizontal, 16)
                } else if filtered.isEmpty {
                    Text("No reviews yet").foregroundColor(.secondary).padding()
                } else {
                    VStack(spacing: 14) {
                        ForEach(filtered) { r in
                            let rname = restaurantsById[r.restaurantId]?.name ?? "—"
                            ReviewCard(
                                author: userName,
                                restaurant: rname,
                                rating: r.stars,
                                comment: r.comment,
                                avatarURL: "",                       // si luego usas avatar
                                reviewImageURL: r.imageURL           // NUEVO (opcional)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, embedded ? 0 : 8)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .userReviewsDidChange)) { _ in
            Task { await load() }
        }
    }

    private var filtered: [Review] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return reviews }
        return reviews.filter { rev in
            let rname = restaurantsById[rev.restaurantId]?.name.lowercased() ?? ""
            return rev.comment.lowercased().contains(q) || rname.contains(q)
        }
    }

    private func load() async {
        loading = true; error = nil
        do {
            // nombre del usuario
            if let u = try await usersRepo.getCurrentUser() {
                userName = u.name
            }
            // reviews del usuario
            let items = try await reviewsRepo.listMyReviews()
            self.reviews = items

            // traer nombres de restaurantes
            let ids = Array(Set(items.map { $0.restaurantId }))
            let rests = try await restaurantsRepo.getMany(ids: ids)
            self.restaurantsById = Dictionary(uniqueKeysWithValues: rests.map { ($0.id, $0) })
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
