//
//  ReviewsController.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

import Foundation
import UIKit

final class ReviewsController: ObservableObject {
    @Published var isSubmitting = false
    @Published var errorMsg: String?

    private let repo = ReviewsRepository()

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
}
