//
//  SegmentedTabs.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 19/09/25.
//

import SwiftUI

struct SegmentedTabs: View {
    private let items = ["Home", "Favorites", "Offers", "Review History"]
    @Binding var selectedIndex: Int

    private enum TabDest: Hashable { case home, favorites, offers, review }
    @State private var navTarget: TabDest?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { idx in
                Button {
                    selectedIndex = idx
                    switch idx {
                    case 0: navTarget = .home
                    case 1: navTarget = .favorites
                    case 2: navTarget = .offers
                    case 3: navTarget = .review
                    default: break
                    }
                } label: {
                    Text(items[idx])
                        .font(.system(size: 11, weight: .semibold))
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
        .background(
            Group {
                NavigationLink(
                    tag: .home,
                    selection: $navTarget,
                    destination: { UserHomeView() },
                    label: { EmptyView() }
                )
                .hidden()

                NavigationLink(
                    tag: .favorites,
                    selection: $navTarget,
                    destination: { FavoritesUserView() },
                    label: { EmptyView() }
                )
                .hidden()

                NavigationLink(
                    tag: .offers,
                    selection: $navTarget,
                    destination: { OffersUserView() },
                    label: { EmptyView() }
                )
                .hidden()

                NavigationLink(
                    tag: .review,
                    selection: $navTarget,
                    destination: { ReviewHistoryUserView() },
                    label: { EmptyView() }
                )
                .hidden()
            }
        )
    }
}
