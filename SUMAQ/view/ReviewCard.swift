//
//  ReviewCard.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 20/09/25.
//
import SwiftUI

struct ReviewCard: View {
    let author: String
    let restaurant: String
    let rating: Double
    let comment: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Encabezado: autor - restaurante  +  estrellas
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 0) {
                    Text(author)
                        .font(.custom("Monserrat-Semibold", size:14, relativeTo: .headline))
                        .foregroundStyle(.primary)

                    Text(" - ")
                        .font(.custom("Monserrat-Semibold", size:14, relativeTo: .headline))
                        .foregroundStyle(.primary)

                    Text(restaurant)
                        .font(.custom("Monserrat-Semibold", size:14, relativeTo: .headline))
                        .foregroundStyle(Palette.purple)
                        .underline(true, color: Palette.purple)
                }

                Spacer(minLength: 8)

                StarsView(
                    rating: rating
                )
            }

            // Comentario
            Text(comment)
                .font(.custom("Monserrat-Semibold", size:18, relativeTo: .headline))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Palette.grayLight, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
    }
}
