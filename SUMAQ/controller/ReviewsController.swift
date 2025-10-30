//
//  ReviewsController.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

import Foundation
import UIKit
import Combine

final class ReviewsController: ObservableObject {
    @Published var isSubmitting = false
    @Published var errorMsg: String?
    @Published var reviews: [Review] = []
    
    private let repo = ReviewsRepository()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Auto-cleanup on deinit
    }
    
    deinit {
        cancellables.removeAll()
    }

    func submit(restaurantId: String,
                stars: Int,
                comment: String,
                imageData: Data?) {
        isSubmitting = true
        errorMsg = nil

        Task {
            do {
                try await repo.createReview(restaurantId: restaurantId, stars: stars, comment: comment, imageData: imageData)
                await MainActor.run {
                    self.isSubmitting = false
                    NotificationCenter.default.post(name: .userReviewsDidChange, object: nil)
                    NotificationCenter.default.post(name: .reviewDidCreate, object: nil)
                }
            } catch {
                await MainActor.run {
                    self.isSubmitting = false
                    self.errorMsg = error.localizedDescription
                }
            }
        }
    }
    
    /// Starts listening to reviews for a restaurant in real-time
    func startListening(to restaurantId: String) {
        repo.reviewsPublisher(for: restaurantId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMsg = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] newReviews in
                    self?.reviews = newReviews
                }
            )
            .store(in: &cancellables)
    }
    
    /// Stops listening to reviews
    func stopListening() {
        cancellables.removeAll()
    }
}
