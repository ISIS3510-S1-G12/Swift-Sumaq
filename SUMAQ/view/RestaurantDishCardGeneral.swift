//
//  RestaurantDishCardGeneral.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 20/09/25.
//

import SwiftUI

struct RestaurantDishCardGeneral: View {
    let title: String
    let subtitle: String
    let imageName: String
    let rating: Double           // 0...5

    var body: some View {
        HStack(spacing: 0) {

            // Panel de texto y estrellas
            VStack(alignment: .leading, spacing: 8) {
                StarsView(rating: rating)
                Text(title)
                    .font(.custom("Montserrat-SemiBold", size: 16))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.custom("Montserrat-Regular", size: 13))
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.purple)

            // Imagen (sin botón)
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 140, height: 105)
                .clipped()
        }
        .frame(height: 110)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 6)
        .padding(.horizontal, 4)
    }
}

#Preview {
    VStack(spacing: 14) {
        RestaurantDishCardGeneral(
            title: "Bacon Sandwich",
            subtitle: "Hamburger with a lot of bacon.",
            imageName: "Dish1",
            rating: 4
        )
        RestaurantDishCardGeneral(
            title: "BBQ Sandwich",
            subtitle: "Hamburger with a lot of BBQ.",
            imageName: "Dish2",
            rating: 4
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
