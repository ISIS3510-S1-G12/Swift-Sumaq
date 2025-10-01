// /repostories/ReviewRepository.swift

import UIKit

protocol ReviewRepository {
    // user side
    func listenUserReviews(userId: String) -> AsyncStream<[Review]>
    func fetchUserReviewsOnce(userId: String) async throws -> [Review]
    func createUserReview(
        userId: String,
        authorUsername: String,
        restaurantId: String,
        rating: Double,
        comment: String,
        photo: UIImage?
    ) async throws -> String
}
