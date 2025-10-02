//  RestaurantTopBar.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDOÑO on 20/09/25.
//

import SwiftUI

struct RestaurantTopBar: View {
    var restaurantLogo: String
    var appLogo: String = "AppLogo"
    private let lineColor: Color = Palette.burgundy
    private let lineHeight: CGFloat = 1
    private let sidePadding: CGFloat = 16

    var showBack: Bool = false

    var onBack: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            if showBack {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                        Text("Back")
                            .font(.system(size: 17, weight: .regular))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.accentColor)
                .padding(.vertical, 6)
            } else {
                Image(appLogo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Spacer()

            Image(restaurantLogo)
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
                .shadow(radius: 2, y: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)

        Rectangle()
            .fill(lineColor)
            .frame(height: lineHeight)
            .padding(.horizontal, sidePadding)

    }
}
