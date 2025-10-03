//
//  TopBar.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 19/09/25.
//

import SwiftUI

// MARK: - Top bar (logo + nombre de sesión + avatar) + línea inferior
struct TopBar: View {
    private let lineColor: Color = Palette.burgundy
    private let lineHeight: CGFloat = 1
    private let sidePadding: CGFloat = 16

    @ObservedObject private var session = SessionController.shared

    private var displayName: String {
        if let n = session.currentUser?.name, !n.isEmpty { return n }
        return "Mi sesión"
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Logo app
                Image("AppLogoUI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Spacer()

                HStack(spacing: 8) {
                    Text(displayName)
                        .font(.custom("Montserrat-SemiBold", size: 16))
                        .foregroundColor(Palette.burgundy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, sidePadding)

            Rectangle()
                .fill(lineColor)
                .frame(height: lineHeight)
                .padding(.horizontal, sidePadding)
        }
    }
}
