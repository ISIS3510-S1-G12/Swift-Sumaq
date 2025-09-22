//
//  RestaurantDetsSegmentedTab.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 20/09/25.
//


import SwiftUI

struct RestaurantDetsSegmentedTab: View {
    private let items = ["Menú", "Offers", "Review"]
    @Binding var selectedIndex: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { idx in
                Button {
                    selectedIndex = idx
                } label: {
                    Text(items[idx])
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(idx == selectedIndex ? Palette.orange : .primary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if idx < items.count - 1 {
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(width: 1, height: 18)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Palette.grayLight, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
        )
        .padding(.horizontal, 16)
    }
}
