import SwiftUI

struct OffersUserView: View {
    var embedded: Bool = false

    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionOffersView? = nil
    @State private var selectedTab = 2

    @State private var offers: [Offer] = []
    @State private var restaurantsById: [String: Restaurant] = [:]
    @State private var loading = true
    @State private var error: String?

    private let offersRepo = OffersRepository()
    private let restaurantsRepo = RestaurantsRepository()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !embedded {
                    TopBar()
                    SegmentedTabs(selectedIndex: $selectedTab)
                }

                SearchFilterChatBar(
                    text: $searchText,
                    selectedFilter: $selectedFilter,
                    onChatTap: { }
                )
                .padding(.horizontal, 16)

                if loading {
                    ProgressView().padding()
                } else if let error {
                    Text(error).foregroundColor(.red).padding(.horizontal, 16)
                } else if offersFiltered.isEmpty {
                    Text("No offers available").foregroundColor(.secondary).padding()
                } else {
                    // Secciones por restaurante
                    ForEach(groupedByRestaurant.keys.sorted(), id: \.self) { rid in
                        Group {
                            OffersSectionHeader(title: restaurantsById[rid]?.name ?? "Restaurant")
                            VStack(spacing: 12) {
                                ForEach(groupedByRestaurant[rid] ?? []) { off in
                                    OfferCard(
                                        title: off.title,
                                        description: off.description,
                                        imageURL: off.image
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.top, embedded ? 0 : 8)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .task { await load() }
    }

    // MARK: helpers
    private var offersFiltered: [Offer] {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return offers }
        return offers.filter {
            $0.title.lowercased().contains(term)
            || $0.description.lowercased().contains(term)
            || $0.tags.joined(separator: " ").lowercased().contains(term)
        }
    }

    private var groupedByRestaurant: [String: [Offer]] {
        Dictionary(grouping: offersFiltered, by: { $0.restaurantId })
    }

    private func load() async {
        loading = true; error = nil
        do {
            let offs = try await offersRepo.listAll()
            self.offers = offs
            let rests = try await restaurantsRepo.all()
            self.restaurantsById = Dictionary(uniqueKeysWithValues: rests.map { ($0.id, $0) })
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

private struct OffersSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.custom("Montserrat-Bold", size: 24))
            .foregroundStyle(Palette.purple)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}
