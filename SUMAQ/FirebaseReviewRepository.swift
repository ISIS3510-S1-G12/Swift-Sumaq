// /repositories/FirebaseReviewRepository.swift

import FirebaseFirestore
import FirebaseStorage
import UIKit

final class FirebaseReviewRepository: ReviewRepository {
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    private var reviewsCol: CollectionReference { db.collection("Reviews") }

    // MARK: - Streams (realtime)
    func listenUserReviews(userId: String) -> AsyncStream<[Review]> {
        AsyncStream { continuation in
            let listener = reviewsCol
                .whereField("user_id", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .addSnapshotListener { snap, error in
                    if let error { print("listenUserReviews error:", error) }
                    guard let docs = snap?.documents else { return }
                    let mapped: [Review] = docs.compactMap { doc in
                        Review.fromFirestore(id: doc.documentID, doc.data())
                    }
                    continuation.yield(mapped)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - One-shot
    func fetchUserReviewsOnce(userId: String) async throws -> [Review] {
        let qs = try await reviewsCol
            .whereField("user_id", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return qs.documents.compactMap { Review.fromFirestore(id: $0.documentID, $0.data()) }
    }

    // MARK: - Create (with optional photo)
    func createUserReview(
        userId: String,
        authorUsername: String,
        restaurantId: String,
        rating: Double,
        comment: String,
        photo: UIImage?
    ) async throws -> String {

        let newRef = reviewsCol.document()
        let reviewId = newRef.documentID

        var photoURL: URL? = nil
        if let photo {
            let jpegData = photo.jpegData(compressionQuality: 0.85) ?? Data()
            let storageRef = storage.reference(withPath: "review_images/\(userId)/\(reviewId).jpg")
            _ = try await storageRef.putDataAsync(jpegData, metadata: .init(contentType: "image/jpeg"))
            let url = try await storageRef.downloadURL()
            photoURL = url
        }

        let review = Review(
            id: reviewId,
            userId: userId,
            restaurantId: restaurantId,
            authorUsername: authorUsername,
            rating: rating,
            comment: comment,
            createdAt: Date(),        
            photoURL: photoURL
        )

        var data = review.asFirestore
        data["createdAt"] = FieldValue.serverTimestamp() 
        try await newRef.setData(data, merge: false)
        return reviewId
    }
}

