//
//  RestaurantTopBar.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDO�O on 20/09/25.
//

import Foundation
import SwiftUI

struct RestaurantTopBar: View {
    var restaurantLogo: String
    var appLogo: String = "AppLogo"
    private let lineColor: Color = Palette.burgundy   // cámbialo por Palette.purple / .orange, etc.
    private let lineHeight: CGFloat = 1               // grosor de la línea
    private let sidePadding: CGFloat = 16

    var body: some View {
        HStack {
            // App Logo
            Image(appLogo)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Spacer()

            // Restaurante logo
            Image(restaurantLogo)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(radius: 2, y: 1)
        }
        .padding(.horizontal, 16)
        // Línea inferior
        Rectangle()
            .fill(lineColor)
            .frame(height: lineHeight)
            .padding(.horizontal, sidePadding)
    }
}
