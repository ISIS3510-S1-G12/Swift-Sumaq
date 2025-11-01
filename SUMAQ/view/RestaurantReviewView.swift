//
//  RestaurantReviewView.swift
//  SUMAQ
//
//  Created by RODRIGO PAZ LONDO�O on 20/09/25.
//

import SwiftUI
import Combine

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
    
    // Combine - Real-time streaming
    @State private var reviewsCancellable: AnyCancellable?
    @State private var isSubscribedToPublisher = false
    
    private let reviewsRepo = ReviewsRepository()
    private let usersRepo = UsersRepository()
    private let localStore = LocalStore.shared
    
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
            // Start real-time streaming with Combine
            startRealTimeUpdates()
        }
        .onDisappear {
            // Cancel Combine subscription
            stopRealTimeUpdates()
        }
        .task {
            guard !isLoadingData else { return }
            await loadReviews()
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
            
            // Hybrid approach: Load from SQLite first (fast, offline-first strategy intact)
            if let localRecords = try? localStore.reviews.listForRestaurant(restaurantId),
               !localRecords.isEmpty {
                let localReviews = localRecords.map { toReview(from: $0) }
                    .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
                
                await MainActor.run {
                    self.reviews = localReviews
                }
                
                // Load user data for local reviews
                await loadUserData(for: localReviews)
            }
            
            // Then load from Firestore (listForRestaurant has offline-first built in)
            let list = try await reviewsRepo.listForRestaurant(restaurantId)
            
            // Only update if we got new data (Combine will handle real-time updates)
            if !list.isEmpty {
                await MainActor.run {
                    self.reviews = list
                }
                await loadUserData(for: list)
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }
    
    private func loadUserData(for reviewsToLoad: [Review]) async {
        let ids = Array(Set(reviewsToLoad.map { $0.userId }))
        guard !ids.isEmpty else { 
            await MainActor.run {
                self.userNamesById = [:]
                self.userAvatarsById = [:]
            }
            return 
        }
        
        // Check cache first for immediate display
        let cache = UserBasicDataCache.shared
        let cachedData = cache.getUsersData(userIds: ids)
        
        if !cachedData.isEmpty {
            var names: [String: String] = [:]
            var avatars: [String: String] = [:]
            for (userId, data) in cachedData {
                names[userId] = data.name
                if let url = data.avatarURL, !url.isEmpty {
                    avatars[userId] = url
                }
            }
            // Update UI immediately with cached data
            await MainActor.run {
                self.userNamesById.merge(names) { _, new in new }
                self.userAvatarsById.merge(avatars) { _, new in new }
            }
        }
        
        // Fetch fresh data in background (populates cache automatically)
        do {
            let users = try await usersRepo.getManyBasic(ids: ids)
            var names: [String: String] = [:]
            var avatars: [String: String] = [:]
            for user in users { 
                names[user.id] = user.name
                if let url = user.profilePictureURL, !url.isEmpty {
                    avatars[user.id] = url
                }
            }
            // Update UI with fresh data
            await MainActor.run {
                self.userNamesById = names
                self.userAvatarsById = avatars
            }
        } catch {
            // Non-fatal: user data is optional
        }
    }
    
    // MARK: - Combine Real-Time Streaming
    private func startRealTimeUpdates() {
        guard !isSubscribedToPublisher,
              let restaurantId = session.currentRestaurant?.id else { return }
        isSubscribedToPublisher = true
        
        // Subscribe to real-time reviews publisher
        reviewsCancellable = reviewsRepo.reviewsPublisher(for: restaurantId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let err) = completion {
                        // Only show error if we don't have local data
                        if self.reviews.isEmpty {
                            self.error = err.localizedDescription
                        }
                    }
                },
                receiveValue: { newReviews in
                    // Update reviews from real-time stream
                    self.reviews = newReviews
                    
                    // Update SQLite cache in background (existing strategy remains intact)
                    Task.detached { [localStore = self.localStore] in
                        for review in newReviews {
                            try? localStore.reviews.upsert(ReviewRecord(from: review))
                        }
                    }
                    
                    // Load user data for the new reviews
                    Task {
                        await self.loadUserData(for: newReviews)
                    }
                }
            )
    }
    
    private func stopRealTimeUpdates() {
        reviewsCancellable?.cancel()
        reviewsCancellable = nil
        isSubscribedToPublisher = false
    }
    
    // Helper to convert ReviewRecord to Review
    private func toReview(from record: ReviewRecord) -> Review {
        Review(
            id: record.id,
            userId: record.userId,
            restaurantId: record.restaurantId,
            stars: record.stars,
            comment: record.comment,
            imageURL: record.imageUrl,
            createdAt: record.createdAt
        )
    }
}
