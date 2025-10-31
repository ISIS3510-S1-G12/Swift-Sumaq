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
    @State private var userAvatarsById: [String: String] = [:]
    @State private var loading = true
    @State private var error: String?
    
    // Network connectivity
    @State private var hasInternetConnection = true
    @State private var hasCheckedConnectivity = false
    @State private var isLoadingData = false
    
    private let reviewsRepo = ReviewsRepository()
    private let usersRepo = UsersRepository()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Number of reviews: \(reviews.count)")
                .font(.custom("Montserrat-SemiBold", size: 16))
                .foregroundColor(Palette.orangeAlt)
                .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 16) {
                Text("Reviews")
                    .font(.custom("Montserrat-SemiBold", size: 16))
                    .foregroundColor(Palette.teal)
                    .padding(.horizontal, 16)

                if loading {
                    ProgressView().padding()
                    Text("Loading Reviews…")
                        .font(.custom("Montserrat-Regular", size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("If you are having a slow connection or if you are offline, we will show you the saved reviews in a moment.")
                        .font(.custom("Montserrat-Regular", size: 12))
                        .foregroundStyle(.secondary.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else if let error {
                    VStack(spacing: 12) {
                        if !hasInternetConnection {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("No internet connection")
                                .font(.custom("Montserrat-SemiBold", size: 16))
                                .foregroundStyle(.primary)
                            Text("We couldn't load the reviews. Please check your internet connection and try again.")
                                .font(.custom("Montserrat-Regular", size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        } else {
                            Text(error)
                                .font(.custom("Montserrat-Regular", size: 14))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                    }
                    .padding(.vertical, 16)
                } else if reviews.isEmpty {
                    Text("No reviews yet").foregroundColor(.secondary).padding(.horizontal, 16)
                } else {
                    ForEach(reviews) { review in
                        let author = userNamesById[review.userId] ?? "#\(review.userId.suffix(5))"
                        let avatar = userAvatarsById[review.userId] ?? ""
                        ReviewCard(
                            author: author,
                            restaurant: "—",
                            rating: review.stars,
                            comment: review.comment,
                            avatarURL: avatar,
                            reviewImageURL: review.imageURL,
                            reviewLocalPath: review.imageLocalPath
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .onAppear {
            // Check internet connection only once
            if !hasCheckedConnectivity {
                checkInternetConnection()
                hasCheckedConnectivity = true
            }
        }
        .task {
            guard !isLoadingData else { return }
            await loadReviews()
        }
        .onReceive(NotificationCenter.default.publisher(for: .userReviewsDidChange)) { _ in
            Task {
                guard !isLoadingData else { return }
                await loadReviews()
            }
        }
    }
    
    // MARK: - Network Connectivity
    private func checkInternetConnection() {
        // Use simple synchronous check for immediate UI update
        hasInternetConnection = NetworkHelper.shared.isConnectedToNetwork()
        
        // Also use async check for more accurate result (only update if different to avoid unnecessary re-renders)
        NetworkHelper.shared.checkNetworkConnection { isConnected in
            Task { @MainActor in
                if self.hasInternetConnection != isConnected {
                    self.hasInternetConnection = isConnected
                }
            }
        }
    }
    
    private func loadReviews() async {
        guard let restaurantId = session.currentRestaurant?.id else { return }
        
        // Prevent multiple simultaneous loads
        guard !isLoadingData else { return }
        isLoadingData = true
        
        loading = true
        error = nil
        defer { 
            loading = false
            isLoadingData = false
        }
        
        do {
            // Check for cancellation before proceeding
            try Task.checkCancellation()
            let list = try await reviewsRepo.listForRestaurant(restaurantId)
            self.reviews = list
            
            let ids = Array(Set(list.map { $0.userId }))
            guard !ids.isEmpty else { 
                self.userNamesById = [:]
                return 
            }
            
            let users = try await usersRepo.getManyBasic(ids: ids)
            var names: [String: String] = [:]
            var avatars: [String: String] = [:]
            for user in users { 
                names[user.id] = user.name
                if let url = user.profilePictureURL, !url.isEmpty {
                    avatars[user.id] = url
                }
            }
            self.userNamesById = names
            self.userAvatarsById = avatars
        } catch {
            self.error = error.localizedDescription
        }
    }
}
