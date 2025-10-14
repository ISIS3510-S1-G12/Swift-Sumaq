//
//  RestaurantReviewView.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDO�O on 20/09/25.
//

import SwiftUI

struct ReviewsContent: View {
    @ObservedObject private var session = SessionController.shared
    
    @State private var reviews: [Review] = []
    @State private var userNamesById: [String: String] = [:]
    @State private var loading = true
    @State private var error: String?
    
    private let reviewsRepo = ReviewsRepository()
    private let usersRepo = UsersRepository()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Número de reviews dinámico
            Text("Number of reviews: \(reviews.count)")
                .font(.custom("Montserrat-SemiBold", size: 16))
                .foregroundColor(Palette.orangeAlt)
                .padding(.horizontal, 16)
    
            VStack(alignment: .leading, spacing: 12) {
                Text("Views Statistics")
                    .font(.custom("Montserrat-SemiBold", size: 16))
                    .foregroundColor(Palette.teal)

                Image("PopularTimes")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 16) {
                Text("Reviews")
                    .font(.custom("Montserrat-SemiBold", size: 16))
                    .foregroundColor(Palette.teal)
                    .padding(.horizontal, 16)

                if loading {
                    ProgressView().padding()
                } else if let error {
                    Text(error).foregroundColor(.red).padding(.horizontal, 16)
                } else if reviews.isEmpty {
                    Text("No reviews yet").foregroundColor(.secondary).padding(.horizontal, 16)
                } else {
                    ForEach(reviews) { review in
                        let author = userNamesById[review.userId] ?? "#\(review.userId.suffix(5))"
                        ReviewCard(
                            author: author,
                            restaurant: "—",
                            rating: review.stars,
                            comment: review.comment,
                            avatarURL: "",
                            reviewImageURL: review.imageURL
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .task { await loadReviews() }
        .onReceive(NotificationCenter.default.publisher(for: .userReviewsDidChange)) { _ in
            Task { await loadReviews() }
        }
    }
    
    private func loadReviews() async {
        guard let restaurantId = session.currentRestaurant?.id else { return }
        
        loading = true
        error = nil
        defer { loading = false }
        
        do {
            let list = try await reviewsRepo.listForRestaurant(restaurantId)
            self.reviews = list
            
            let ids = Array(Set(list.map { $0.userId }))
            guard !ids.isEmpty else { 
                self.userNamesById = [:]
                return 
            }
            
            let users = try await usersRepo.getManyBasic(ids: ids)
            var map: [String: String] = [:]
            for user in users { 
                map[user.id] = user.name 
            }
            self.userNamesById = map
        } catch {
            self.error = error.localizedDescription
        }
    }
}
