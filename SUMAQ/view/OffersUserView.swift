import SwiftUI
import MapKit

struct OffersUserView: View {
    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionOffersView? = nil
    @State private var selectedTab = 2

    var body: some View {

        ScrollView {
            VStack(spacing: 16) {
                TopBar()

                SegmentedTabs(selectedIndex: $selectedTab)

                SearchFilterChatBar(
                    text: $searchText,
                    selectedFilter: $selectedFilter,
                    onChatTap: { /* abrir chatbot */ }
                )
                .padding(.horizontal, 16)

                Group {
                    SectionHeader(title: "Lucille")

                    OfferCard(
                        title: "Extra Bacon",
                        description: "Hamburger with free bacon.",
                        rating: 4.0,
                        image: Image("offer_lucille")
                    )
                }
                .padding(.horizontal, 16)

                Group {
                    SectionHeader(title: "La Puerta")

                    OfferCard(
                        title: "2 x 1",
                        description: "2 Hamburger for the price of 1.",
                        rating: 4.0,
                        image: Image("offer_lapuerta")
                    )
                }
                .padding(.horizontal, 16)

                Group {
                    SectionHeader(title: "Santo Gyro")

                    OfferCard(
                        title: "2 Gyro offer",
                        description: "2 pork gyros at a lower price.",
                        rating: 5.0,
                        image: Image("offer_gyro")          
                    )
                }
                .padding(.horizontal, 16)


                Spacer(minLength: 24)
            }
            .padding(.top, 8)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.custom("Montserrat-Bold", size: 24))
            .foregroundStyle(Palette.purple)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}


#Preview { OffersUserView() }
