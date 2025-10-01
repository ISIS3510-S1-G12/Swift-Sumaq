import SwiftUI

struct FavoritesUserView: View {
    var embedded: Bool = false

    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionFavoritesView? = nil
    @State private var selectedTab = 1

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !embedded {
                    TopBar()
                    SegmentedTabs(selectedIndex: $selectedTab)
                    Rectangle()
                        .fill(Palette.burgundy)
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }

                SearchFilterChatBar<FilterOptionFavoritesView>(
                    text: $searchText,
                    selectedFilter: $selectedFilter,
                    onChatTap: { },
                    config: .init(searchColor: Palette.orange, ringColor: Palette.orange)
                )
                .padding(.horizontal, 16)

                // Mocks (luego reemplazamos por favoritos reales)
                VStack(spacing: 14) {
                    RestaurantCard(name: "La Puerta", category: "Burgers restaurant", tag: "Offers", rating: 4.0, imageURL: "logo_puerta", panelColor: Palette.purpleLight)
                    RestaurantCard(name: "Chick & Chips", category: "Chicken restaurant", tag: "Offers", rating: 5.0, imageURL: "logo_chick", panelColor: Palette.purpleLight)
                    RestaurantCard(name: "Chicken Lovers", category: "Chicken restaurant", tag: "Offers", rating: 4.0, imageURL: "logo_chicken", panelColor: Palette.purpleLight)
                    RestaurantCard(name: "Lucille", category: "Sandwich", tag: "Offers", rating: 4.0, imageURL: "logo_lucille", panelColor: Palette.purpleLight)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .padding(.top, embedded ? 0 : 8)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

#Preview { FavoritesUserView() }
