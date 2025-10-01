import SwiftUI

struct ReviewHistoryUserView: View {
    var embedded: Bool = false

    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionReviewHistoryView? = nil
    @State private var selectedTab = 3

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

                VStack(spacing: 14) {
                    ReviewCard(author: "rpl_03", restaurant: "Centro de Japon", rating: 5, comment: "Best meal ever")
                    ReviewCard(author: "rpl_03", restaurant: "Monserrat", rating: 3, comment: "Its fine")
                    ReviewCard(author: "rpl_03", restaurant: "Cunks BBQ", rating: 4, comment: "I really like this")
                    ReviewCard(author: "rpl_03", restaurant: "Mulita", rating: 1, comment: "I will not buy this again")
                    ReviewCard(author: "rpl_03", restaurant: "Jack Daniels", rating: 5, comment: "I loved this hamburger so much")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .padding(.top, embedded ? 0 : 8)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

#Preview { ReviewHistoryUserView() }
