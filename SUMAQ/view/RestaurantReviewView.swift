//
//  RestaurantReviewView.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDO�O on 20/09/25.
//

import SwiftUI

struct ReviewsContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

             // Header
            RestaurantTopBar(restaurantLogo: "AppLogoUI", appLogo: "AppLogoUI", showBack: true)

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
    }
}
