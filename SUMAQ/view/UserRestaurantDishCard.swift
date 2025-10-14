//
//  UserRestaurantDishCard.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//

import SwiftUI

struct UserRestaurantDishCard: View {
    let title: String
    let subtitle: String
    let imageURL: String
    let rating: Int

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                StarsRow(rating: rating)
                Text(title)
                    .font(.custom("Montserrat-SemiBold", size: 16))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.custom("Montserrat-Regular", size: 13))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.purpleLight)

            RemoteImage(urlString: imageURL)
                .frame(width: 140, height: 110)
                .clipped()
        }
        .frame(height: 110)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .compositingGroup()
        .shadow(color: .black.opacity(0.08), radius: 8, y: 6)
        .padding(.horizontal, 4)
    }
}
