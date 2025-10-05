//
//  UserSegmentedTab.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

import SwiftUI

struct UserSegmentedTab: View {
    @Binding var selectedIndex: Int
    var onSelect: ((Int) -> Void)? = nil

    private let items = ["Home", "Favorites", "Offers", "Review History"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { idx in
                Button {
                    selectedIndex = idx
                    onSelect?(idx)
                } label: {
                    Text(items[idx])
                        .font(.custom("Montserrat-SemiBold", size: 14))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundColor(idx == selectedIndex ? Palette.orange : .primary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
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
            RoundedRectangle(cornerRadius: 22)
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
