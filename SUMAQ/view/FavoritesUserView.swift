
import SwiftUI

struct FavoritesUserView: View {
    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionFavoritesView? = nil
    @State private var selectedTab = 1   // 0: Home | 1: Favorites | 2: Offers | 3: Review

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TopBar()

                SegmentedTabs(selectedIndex: $selectedTab)

                Rectangle()
                    .fill(Palette.burgundy)
                    .frame(height: 1)
                    .padding(.horizontal, 16)


                SearchFilterChatBar<FilterOptionFavoritesView>(
                    text: $searchText,
                    selectedFilter: $selectedFilter,
                    onChatTap: { /* abrir chatbot */ },
                    config: .init(
                        searchColor: Palette.orange,
                        ringColor:   Palette.orange
                    )
                )
                .padding(.horizontal, 16)

                VStack(spacing: 14) {

                    RestaurantCard(
                        name: "La puerta",
                        category: "Burgers restaurant",
                        tag: "Offers",
                        rating: 4.0,
                        image: Image("logo_puerta")

                    )

                    RestaurantCard(
                        name: "Chick & Chips",
                        category: "Chicken restaurant",
                        tag: "Offers",
                        rating: 5.0,
                        image: Image("logo_chick")

                    )

                    RestaurantCard(
                        name: "Chicken Lovers",
                        category: "Chicken restaurant",
                        tag: "Offers",
                        rating: 4.0,
                        image: Image("logo_chicken")

                    )

                    RestaurantCard(
                        name: "Lucille",
                        category: "Sandwich",
                        tag: "Offers",
                        rating: 4.0,
                        image: Image("logo_lucille")

                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

#Preview { FavoritesUserView() }
