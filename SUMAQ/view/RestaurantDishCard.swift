//
//  RestaurantDishCard.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDO�O on 20/09/25.
//

import SwiftUI

struct StarsRow: View {
    let rating: Int
    let max: Int = 5
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max, id: \.self) { i in
                Image(systemName: i < rating ? "star.fill" : "star")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .opacity(i < rating ? 1 : 0.85)
            }
        }
        .accessibilityLabel("Rating")
        .accessibilityValue("\(rating) of \(max) stars")
    }
}

struct RestaurantDishCard: View {
    let title: String
    let subtitle: String
    let imageURL: String           // dataURL
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
            }
            .padding(14)
            .frame(maxWidth: .infinity,
                   maxHeight: .infinity,
                   alignment: .leading)
            .background(Palette.tealLight)

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
