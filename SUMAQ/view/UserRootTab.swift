//
//  UserRootTab.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

import SwiftUI

struct UserRootView: View {
    @State private var selectedTab = 0
    @State private var showProfile = false   // 👈 NUEVO

    var body: some View {
        NavigationStack {                    // asegúrate de tener NavigationStack aquí
            VStack(spacing: 16) {
                TopBar(onAvatarTap: {        // 👈 aquí sí usamos el callback
                    showProfile = true
                })

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
            .background(
                NavigationLink(
                    destination: UserProfileView(),   // tu vista de perfil
                    isActive: $showProfile,
                    label: { EmptyView() }
                )
                .hidden()
            )
        }
    }
}
