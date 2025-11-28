// ReviewHistoryUserView.swift
// SUMAQ

import SwiftUI
import Combine

struct ReviewHistoryUserView: View {
    var embedded: Bool = false

    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionReviewHistoryView? = nil
    @State private var selectedTab = 3

    @ObservedObject private var session = SessionController.shared
    @State private var loading = true
    @State private var error: String?
    @State private var reviews: [Review] = []
    @State private var userName: String = "You"
    @State private var userAvatarURL: String = ""
    @State private var restaurantsById: [String: Restaurant] = [:]
    @State private var isLoadingData = false

    // Network connectivity
    @State private var hasInternetConnection = true
    
    // Combine - Real-time streaming
    @State private var reviewsCancellable: AnyCancellable?
    @State private var isSubscribedToPublisher = false

    private let reviewsRepo = ReviewsRepository()
    private let usersRepo = UsersRepository()
    private let restaurantsRepo = RestaurantsRepository()
    private let localStore = LocalStore.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !embedded {
                    TopBar()
                    SegmentedTabs(selectedIndex: $selectedTab)
                }

                FilterBar<FilterOptionReviewHistoryView>(
                    text: $searchText,
                    selectedFilter: $selectedFilter
                )
                .padding(.horizontal, 16)

                if loading {
                    ProgressView().padding()
                    Text("Loading your Reviews…")
                        .font(.custom("Montserrat-Regular", size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Text("If you are having a slow connection or if you are offline, we will show you your saved reviews in a moment.")
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
                            Text("We couldn't load your reviews. Please check your internet connection and try again.")
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
                } else if filtered.isEmpty {
                    Text("No reviews yet").foregroundColor(.secondary).padding()
                } else {
                    VStack(spacing: 14) {
                        ForEach(filtered) { r in
                            let rname = restaurantsById[r.restaurantId]?.name ?? "—"
                            ReviewCard(
                                author: session.currentUser?.name ?? userName,
                                restaurant: rname,
                                rating: r.stars,
                                comment: r.comment,
                                avatarURL: session.currentUser?.profilePictureURL ?? userAvatarURL,
                                reviewImageURL: r.imageURL,
                                reviewLocalPath: r.imageLocalPath
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, embedded ? 0 : 8)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            // Check internet connection
            checkInternetConnection()
            // Start real-time streaming with Combine
            startRealTimeUpdates()
        }
        .onDisappear {
            // Cancel Combine subscription
            stopRealTimeUpdates()
        }
        .task { await load() }
        .navigationBarBackButtonHidden(true)

    }

    private var filtered: [Review] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return reviews }
        return reviews.filter { rev in
            let rname = restaurantsById[rev.restaurantId]?.name.lowercased() ?? ""
            return rev.comment.lowercased().contains(q) || rname.contains(q)
        }
    }

    private func load() async {
        // Prevent multiple simultaneous loads
        guard !isLoadingData else { return }
        isLoadingData = true
        
        loading = true; error = nil
        defer { 
            loading = false
            isLoadingData = false
        }
        
        do {
            // Get current user ID
            guard let uid = session.currentUser?.id else {
                throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No user session"])
            }
            
            // Hybrid approach: Load from SQLite first (fast, offline-first strategy intact)
            if let localRecords = try? localStore.reviews.listForUser(uid),
               !localRecords.isEmpty {
                let localReviews = localRecords.map { toReview(from: $0) }
                    .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
                
                await MainActor.run {
                    self.reviews = localReviews
                }
                
                // Load restaurants for local reviews
                await loadRestaurantsForReviews(localReviews)
            }
            
            // Use GCD to parallelize independent operations (GCD strategy intact)
            let group = DispatchGroup()
            var userResult: AppUser?
            var userError: Error?
            var reviewsResult: [Review] = []
            var reviewsError: Error?
            
            // Load user and reviews in parallel
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                Task {
                    do {
                        userResult = try await self.usersRepo.getCurrentUser()
                    } catch {
                        userError = error
                    }
                    group.leave()
                }
            }
            
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                Task {
                    do {
                        // listMyReviews has offline-first built in, but we've already loaded from SQLite above
                        reviewsResult = try await self.reviewsRepo.listMyReviews()
                    } catch {
                        reviewsError = error
                    }
                    group.leave()
                }
            }
            
            // Wait asynchronously for the group to finish
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                group.notify(queue: .global(qos: .userInitiated)) { cont.resume() }
            }
            
            // Check for errors
            if let e = userError ?? reviewsError { throw e }
            if let u = userResult {
                await MainActor.run {
                    userName = u.name
                    userAvatarURL = u.profilePictureURL ?? ""
                }
            }
            
            // Only update if we got new data (Combine will handle real-time updates)
            if !reviewsResult.isEmpty {
                await MainActor.run {
                    self.reviews = reviewsResult
                }
                await loadRestaurantsForReviews(reviewsResult)
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
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

    // MARK: - Network Connectivity
    private func checkInternetConnection() {
        // Use simple synchronous check for immediate UI update
        hasInternetConnection = NetworkHelper.shared.isConnectedToNetwork()
        
        // Also use async check for more accurate result
        NetworkHelper.shared.checkNetworkConnection { isConnected in
            Task { @MainActor in
                self.hasInternetConnection = isConnected
            }
        }
    }
    
    // MARK: - Combine Real-Time Streaming
    private func startRealTimeUpdates() {
        guard !isSubscribedToPublisher else { return }
        isSubscribedToPublisher = true
        
        // Subscribe to real-time reviews publisher
        reviewsCancellable = reviewsRepo.myReviewsPublisher()
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
                    
                    // Load restaurant names for the new reviews
                    Task {
                        await self.loadRestaurantsForReviews(newReviews)
                    }
                }
            )
    }
    
    private func stopRealTimeUpdates() {
        reviewsCancellable?.cancel()
        reviewsCancellable = nil
        isSubscribedToPublisher = false
    }
    
    private func loadRestaurantsForReviews(_ reviewsToLoad: [Review]) async {
        let ids = Array(Set(reviewsToLoad.map { $0.restaurantId }))
        guard !ids.isEmpty else {
            await MainActor.run {
                self.restaurantsById = [:]
            }
            return
        }
        
        do {
            let restaurants = try await restaurantsRepo.getMany(ids: ids)
            await MainActor.run {
                self.restaurantsById = Dictionary(uniqueKeysWithValues: restaurants.map { ($0.id, $0) })
            }
        } catch {
            // Non-fatal: restaurant names are optional
        }
    }
}

