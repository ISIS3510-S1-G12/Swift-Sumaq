//
//  TopBar.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 19/09/25.
//
import SwiftUI

// MARK: - Top bar (logo + avatar) + línea inferior
struct TopBar: View {
    // Config rápida de la línea
    private let lineColor: Color = Palette.burgundy   // cámbialo por Palette.purple / .orange, etc.
    private let lineHeight: CGFloat = 1               // grosor de la línea
    private let sidePadding: CGFloat = 16

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image("AppLogoUI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, sidePadding)

            // Línea inferior
            Rectangle()
                .fill(lineColor)
                .frame(height: lineHeight)
                .padding(.horizontal, sidePadding)
        }
    }
}
