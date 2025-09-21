//
//  RestaurantReviewView.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDO�O on 20/09/25.
//

import Foundation
import SwiftUI
import MapKit

private enum ReviewRoute: Hashable {
    case offers
}

struct RestaurantReviewView: View {
    @State private var selectedTab: Int = 2
    @State private var searchText: String = ""
    @State private var navPath = NavigationPath()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    RestaurantTopBar(restaurantLogo: "AppLogoUI", appLogo: "AppLogoUI")

                    Text("Lucille")
                        .font(.custom("Montserrat-SemiBold", size: 22))
                        .foregroundColor(Palette.burgundy)
                        .padding(.horizontal, 16)

                    RestaurantSegmentedTab(selectedIndex: $selectedTab) { idx in
                        switch idx {
                        case 0:
                            dismiss()
                        case 1:
                            navPath.append(ReviewRoute.offers)
                        default:
                            break
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    Text("Number of reviews: 100")
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(Palette.orangeAlt)
                        .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Views Statistics")
                            .font(.custom("Montserrat-SemiBold", size: 16))
                            .foregroundColor(Palette.teal)

                        Image("PopularTimes")
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reviews")
                            .font(.custom("Montserrat-SemiBold", size: 16))
                            .foregroundColor(Palette.teal)
                            .padding(.horizontal, 16)

                        ReviewCard(
                            author: "aleL",
                            restaurant: "Bacon Sandwich",
                            rating: 5,
                            comment: "I loved this so much"
                        )

                        ReviewCard(
                            author: "gabyE",
                            restaurant: "Bacon Sandwich",
                            rating: 5,
                            comment: "I do not like chicken, but it was so good"
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
                .padding(.top, 8)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationDestination(for: ReviewRoute.self) { route in
                switch route {
                case .offers:
                    RestaurantOffersView()
                }
            }
        }
    }
}
