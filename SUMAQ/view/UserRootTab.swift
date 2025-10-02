//
//  UserRootTab.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

import SwiftUI

struct UserRootView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 16) {
            TopBar()
            UserSegmentedTab(selectedIndex: $selectedTab)

            Group {
                switch selectedTab {
                case 0:
                    UserHomeView(embedded: true)          
                case 1:
                    FavoritesUserView(embedded: true)
                case 2:
                    OffersUserView(embedded: true)
                case 3:
                    ReviewHistoryUserView(embedded: true)
                default:
                    UserHomeView(embedded: true)
                }
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
