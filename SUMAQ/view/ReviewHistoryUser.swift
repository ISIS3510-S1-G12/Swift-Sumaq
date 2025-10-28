// ReviewHistoryUserView.swift
// SUMAQ

import SwiftUI

struct ReviewHistoryUserView: View {
    var embedded: Bool = false

    @State private var searchText = ""
    @State private var selectedFilter: FilterOptionReviewHistoryView? = nil
    @State private var selectedTab = 3

    @State private var loading = true
    @State private var error: String?
    @State private var reviews: [Review] = []
    @State private var userName: String = "You"
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
                                author: userName,
                                restaurant: rname,
                                rating: r.stars,
                                comment: r.comment,
                                avatarURL: "",
                                reviewImageURL: r.imageURL,               // remoto si existe
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
        
        do {
            // Use GCD to parallelize independent operations
            let group = DispatchGroup()
            var userResult: AppUser?
            var reviewsResult: [Review] = []
            var restaurantsResult: [Restaurant] = []
            var userError: Error?
            var reviewsError: Error?
            var restaurantsError: Error?
            
            // Load current user on background queue
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                defer { group.leave() }
                Task {
                    do {
                        userResult = try await self.usersRepo.getCurrentUser()
                    } catch {
                        userError = error
                    }
                }
            }
            
            // Load reviews on background queue
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                defer { group.leave() }
                Task {
                    do {
                        reviewsResult = try await self.reviewsRepo.listMyReviews()
                    } catch {
                        reviewsError = error
                    }
                }
            }
            
            group.wait()
            
            // Check for errors
            if let error = userError ?? reviewsError {
                throw error
            }
            
            if let u = userResult {
                userName = u.name
            }
            self.reviews = reviewsResult
            
            let ids = Array(Set(reviewsResult.map { $0.restaurantId }))
            
            // Load restaurants in parallel if we have restaurant IDs
            if !ids.isEmpty {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    defer { group.leave() }
                    Task {
                        do {
                            restaurantsResult = try await self.restaurantsRepo.getMany(ids: ids)
                        } catch {
                            restaurantsError = error
                        }
                    }
                }
                group.wait()
                
                if let error = restaurantsError {
                    throw error
                }
                
                self.restaurantsById = Dictionary(uniqueKeysWithValues: restaurantsResult.map { ($0.id, $0) })
            } else {
                self.restaurantsById = [:]
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

