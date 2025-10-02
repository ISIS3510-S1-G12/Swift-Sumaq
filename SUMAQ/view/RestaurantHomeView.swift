//
//  RestaurantHomeView.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDOÑO on 20/09/25.
//


import SwiftUI
import MapKit
import FirebaseAuth

struct RestaurantHomeView: View {
    // 0 = Menú, 1 = Offers, 2 = Review
    @State private var selectedTab: Int = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    RestaurantTopBar(restaurantLogo: "logo_lucille", appLogo: "AppLogoUI",  showBack: true)

                    Text("Lucille")
                        .font(.custom("Montserrat-SemiBold", size: 22))
                        .foregroundColor(Palette.burgundy)
                        .padding(.horizontal, 16)

                    RestaurantSegmentedTab(selectedIndex: $selectedTab) { _ in }
                        .frame(maxWidth: .infinity, alignment: .center)

                    Group {
                        switch selectedTab {
                        case 0:
                            MenuContent()
                        case 1:
                            OffersContent()
                        case 2:
                            ReviewsContent()
                        default:
                            MenuContent()
                        }
                    }
                }
                .padding(.top, 8)
            }
            .background(Color.white.ignoresSafeArea())
        }
    }
}

private struct MenuContent: View {
    @State private var dishes: [Dish] = []
    @State private var loading = true
    @State private var error: String?
    private let repo = DishesRepository()

    var body: some View {
        VStack(spacing: 16) {

            HStack {
                Spacer()
                Button { /* Busiest Hours */ } label: {
                    HStack(spacing: 8) {
                        Text("Busiest Hours")
                            .font(.custom("Montserrat-SemiBold", size: 14))
                        Image(systemName: "chart.bar.fill").font(.subheadline)
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Palette.teal)
                    .clipShape(Capsule())
                }
                Spacer()
            }

            // Lista de Dishes
            if loading {
                ProgressView().padding()
            } else if let error {
                Text(error).foregroundColor(.red).padding(.horizontal, 16)
            } else if dishes.isEmpty {
                Text("No dishes yet").foregroundColor(.secondary).padding()
            } else {
                VStack(spacing: 12) {
                    ForEach(dishes) { d in
                        RestaurantDishCard(
                            title: d.name,
                            subtitle: d.description,
                            imageURL: d.imageUrl,
                            rating: d.rating
                        )
                    }
                }
                .padding(.horizontal, 16)
            }

            HStack {
                Spacer()
                NavigationLink { NewDishView(onCreated: reload) } label: {
                    SmallCapsuleButton(
                        title: "New Dish",
                        background: Palette.orangeAlt,
                        textColor: .white
                    )
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .task { await load() }
    }

    private func load() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        loading = true; error = nil
        do {
            dishes = try await repo.listForRestaurant(uid: uid)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func reload() { Task { await load() } }
}

private struct SmallCapsuleButton: View {
    let title: String
    let background: Color
    let textColor: Color
    var body: some View {
        Text(title)
            .font(.custom("Montserrat-SemiBold", size: 14))
            .foregroundColor(textColor)
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .background(background)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
    }
}
