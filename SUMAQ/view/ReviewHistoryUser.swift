// ReviewHistoryUserView.swift
// SUMAQ

import SwiftUI

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

    private let reviewsRepo = ReviewsRepository()
    private let usersRepo = UsersRepository()
    private let restaurantsRepo = RestaurantsRepository()

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
        }
        .task { await load() }
        .onReceive(NotificationCenter.default.publisher(for: .userReviewsDidChange)) { _ in
            Task { await load() }
        }
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
            // Use GCD to parallelize independent operations
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
                userName = u.name
                userAvatarURL = u.profilePictureURL ?? ""
            }
            self.reviews = reviewsResult
            
            // Load restaurants for the reviews
            let ids = Array(Set(reviewsResult.map { $0.restaurantId }))
            guard !ids.isEmpty else {
                self.restaurantsById = [:]
                return
            }
            
            var restsResult: [Restaurant] = []
            var restsError: Error?
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                Task {
                    do {
                        restsResult = try await self.restaurantsRepo.getMany(ids: ids)
                    } catch {
                        restsError = error
                    }
                    group.leave()
                }
            }
            
            // Wait asynchronously for restaurants to finish
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                group.notify(queue: .global(qos: .userInitiated)) { cont.resume() }
            }
            
            if let e = restsError { throw e }
            self.restaurantsById = Dictionary(uniqueKeysWithValues: restsResult.map { ($0.id, $0) })
        } catch {
            self.error = error.localizedDescription
        }
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
}

