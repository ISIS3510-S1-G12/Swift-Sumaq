//
//  ReviewHistoryUserView.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 20/09/25.
//

import SwiftUI
import MapKit

struct ReviewHistoryUserView: View {

    let userId: String
    let authorUsername: String

    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionReviewHistoryView? = nil
    @State private var selectedTab = 3

    @StateObject private var controller = ReviewsController()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TopBar()
                SegmentedTabs(selectedIndex: $selectedTab)

                FilterBar<FilterOptionReviewHistoryView>(
                    text: $searchText,
                    selectedFilter: $selectedFilter
                )
                .padding(.horizontal, 16)

                VStack(spacing: 14) {
                    ForEach(filteredReviews) { r in
                        ReviewCard(
                            author: r.authorUsername,
                            restaurant: r.restaurantId,
                            rating: r.rating,
                            comment: r.comment
                        )
                    }

                    if filteredReviews.isEmpty, !controller.isLoading {
                        Text("No hay reseñas que coincidan.")
                            .font(.custom("Montserrat-Regular", size: 14))
                            .foregroundColor(Palette.grayDark)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    }

                    if let err = controller.errorMessage {
                        Text(err)
                            .font(.custom("Montserrat-Regular", size: 13))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .padding(.top, 8)
        .onAppear {
            controller.startListeningUserReviews(userId: userId)
        }
        .onDisappear {
            controller.stop()
        }
    }

    // filtro: arreglar despues
    private var filteredReviews: [Review] {
        let base = controller.reviews
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return base }
        let q = searchText.lowercased()
        return base.filter { r in
            r.comment.lowercased().contains(q) ||
            r.authorUsername.lowercased().contains(q) ||
            r.restaurantId.lowercased().contains(q)
        }
    }
}

#Preview {
    // Pasa el uid y username del usuario logueado
    ReviewHistoryUserView(userId: "demo_user_uid", authorUsername: "rpl_03")
}
