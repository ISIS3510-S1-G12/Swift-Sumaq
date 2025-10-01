//
//  ReviewsController.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

import SwiftUI
import Combine
import UIKit

@MainActor
final class ReviewsController: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var reviews: [Review] = []
    @Published var errorMessage: String?

    private let repo: ReviewRepository
    private var streamTask: Task<Void, Never>?

    init(repo: ReviewRepository = FirebaseReviewRepository()) {
        self.repo = repo
    }


    func startListeningUserReviews(userId: String) {
        streamTask?.cancel()
        streamTask = Task {
            for await items in repo.listenUserReviews(userId: userId) {
                self.reviews = items
            }
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
    }

    func loadUserReviewsOnce(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let items = try await repo.fetchUserReviewsOnce(userId: userId)
            self.reviews = items
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func createReview(
        userId: String,
        authorUsername: String,
        restaurantId: String,
        rating: Double,
        comment: String,
        photo: UIImage?
    ) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            _ = try await repo.createUserReview(
                userId: userId,
                authorUsername: authorUsername,
                restaurantId: restaurantId,
                rating: rating,
                comment: comment,
                photo: photo
            )
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
