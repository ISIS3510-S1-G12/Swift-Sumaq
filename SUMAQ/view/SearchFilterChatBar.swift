//
//  SearchFilterChatBar.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 20/09/25.
//

import SwiftUI

struct SearchFilterChatBar: View {
    @Binding var text: String
    @Binding var selectedFilter: FilterOption?
    var onChatTap: () -> Void = {}

    // Tamaño unificado para los botones redondos
    private let diameter: CGFloat = 44
    private let ringLineWidth: CGFloat = 2
    private let ringColor = Palette.orange

    var body: some View {
        HStack(spacing: 10) {
            // Search
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .semibold))

                TextField(
                    "",
                    text: $text,
                    prompt: Text("Search your restaurant")
                        .foregroundStyle(.white.opacity(0.95))
                        .font(.custom("Monserrat-Semibold", size:14, relativeTo: .headline))
                )
                .textInputAutocapitalization(.never)
                .foregroundStyle(.white)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Palette.orangeAlt)
            .foregroundStyle(.white)
            .clipShape(Capsule())

            // Filtro (un solo aro, tamaño fijo)
            Menu {
                Text("Filter by")
                    .font(.custom("Monserrat-Semibold", size:14, relativeTo: .subheadline))
                    .foregroundStyle(.secondary)

                ForEach(FilterOption.allCases) { option in
                    Button {
                        selectedFilter = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if selectedFilter == option { Image(systemName: "checkmark") }
                        }
                    }
                }

                if selectedFilter != nil {
                    Divider()
                    Button("Clear filter", role: .destructive) { selectedFilter = nil }
                }
            } label: {
                RoundIconLabel(systemName: "line.3.horizontal.decrease",
                               diameter: diameter,
                               ringLineWidth: ringLineWidth,
                               color: ringColor)
                .accessibilityLabel("Filter")
            }
            .menuOrder(.fixed)

            // Chat (mismo label redondo)
            Button(action: onChatTap) {
                RoundIconLabel(systemName: "bubble.right",
                               diameter: diameter,
                               ringLineWidth: ringLineWidth,
                               color: ringColor)
                .accessibilityLabel("Chat")
            }
            .buttonStyle(.plain)
        }
    }
}

private struct RoundIconLabel: View {
    let systemName: String
    let diameter: CGFloat
    let ringLineWidth: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: ringLineWidth)
            Image(systemName: systemName)
                .font(.system(size: diameter * 0.45, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
    }
}

