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
                } else if let error {
                    Text(error).foregroundColor(.red).padding(.horizontal, 16)
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
        loading = true; error = nil
        defer { loading = false }
        
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
}

