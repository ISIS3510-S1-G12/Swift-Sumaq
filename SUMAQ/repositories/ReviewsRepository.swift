//
//  ReviewsRepository.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

final class ReviewsRepository {
    private let db = Firestore.firestore()
    private let coll = "Reviews"

    private func currentUid() throws -> String {
        if let uid = Auth.auth().currentUser?.uid { return uid }
        throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No session"])
    }

    func createReview(restaurantId: String,
                      stars: Int,
                      comment: String,
                      imageData: Data?,
                      progress: ((Double) -> Void)? = nil) async throws {
        let uid = try currentUid()
        let ref = db.collection(coll).document()

        var payload: [String: Any] = [
            "user_id": uid,
            "restaurant_id": restaurantId,
            "stars": stars,
            "comment": comment,
            "createdAt": FieldValue.serverTimestamp()
        ]

        if let data = imageData, !data.isEmpty {
            do {
                let localURL = try LocalFileStore.shared.save(
                    data: data,
                    fileName: "\(ref.documentID).jpg",
                    subfolder: "reviews/\(uid)"
                )
                payload["image_local_path"] = localURL.path
            } catch {
                print("Local save error: \(error)")
            }

            let path = "reviews/\(uid)/\(ref.documentID).jpg"
            let urlString = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                StorageService.shared.uploadImageData(data, to: path, contentType: "image/jpeg", progress: progress) { res in
                    switch res {
                    case .success(let url): cont.resume(returning: url)
                    case .failure(let err): cont.resume(throwing: err)
                    }
                }
            }
            payload["imageURL"] = urlString
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            ref.setData(payload) { err in
                if let err { cont.resume(throwing: err) }
                else {
                    NotificationCenter.default.post(name: .userReviewsDidChange, object: nil)
                    NotificationCenter.default.post(name: .reviewDidCreate, object: nil)
                    cont.resume(returning: ())
                }
            }
        }
    }

    func listMyReviews() async throws -> [Review] {
        let uid = try currentUid()
        let qs = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<QuerySnapshot, Error>) in
            db.collection(coll)
                .whereField("user_id", isEqualTo: uid)
                .getDocuments { qs, err in
                    if let err { cont.resume(throwing: err) }
                    else if let qs { cont.resume(returning: qs) }
                    else { cont.resume(throwing: NSError(domain: "Firestore", code: -1)) }
                }
        }

        let items = qs.documents.compactMap { Review(doc: $0) }
        return items.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    func listForRestaurant(restaurantId: String) async throws -> [Review] {
        let qs = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<QuerySnapshot, Error>) in
            db.collection(coll)
                .whereField("restaurant_id", isEqualTo: restaurantId)
                .getDocuments { qs, err in
                    if let err { cont.resume(throwing: err) }
                    else if let qs { cont.resume(returning: qs) }
                    else { cont.resume(throwing: NSError(domain: "Firestore", code: -1)) }
                }
        }

        let items = qs.documents.compactMap { Review(doc: $0) }
        return items.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
    }

    func listForRestaurant(_ restaurantId: String) async throws -> [Review] {
        try await listForRestaurant(restaurantId: restaurantId)
    }
}

// MARK: - Batch Operations
extension ReviewsRepository {
    
    /// Creates multiple reviews in parallel with controlled concurrency
    /// - Parameters:
    ///   - reviews: Array of review data tuples
    ///   - maxConcurrent: Maximum number of concurrent uploads (default: 3)
    ///   - progress: Optional callback for overall batch progress
    /// - Returns: Tuple with success count and array of errors
    func createReviewsBatch(_ reviews: [(restaurantId: String, stars: Int, comment: String, imageData: Data?)],
                           maxConcurrent: Int = 3,
                           progress: ((Int, Int) -> Void)? = nil) async throws -> (success: Int, failures: [Error]) {
        
        guard !reviews.isEmpty else { return (0, []) }
        
        var successCount = 0
        var failures: [Error] = []
        var reviewQueue = reviews
        var completedCount = 0
        
        try await withThrowingTaskGroup(of: Result<Void, Error>.self) { group in
            
            // Start initial batch of tasks
            for _ in 0..<min(maxConcurrent, reviewQueue.count) {
                if let review = reviewQueue.popFirst() {
                    group.addTask {
                        do {
                            try await self.createReview(
                                restaurantId: review.restaurantId,
                                stars: review.stars,
                                comment: review.comment,
                                imageData: review.imageData
                            )
                            return .success(())
                        } catch {
                            return .failure(error)
                        }
                    }
                }
            }
            
            // Process results and add new tasks as they complete
            while let result = try await group.next() {
                completedCount += 1
                
                switch result {
                case .success:
                    successCount += 1
                case .failure(let error):
                    failures.append(error)
                }
                
                // Report progress
                progress?(completedCount, reviews.count)
                
                // Add next review if queue has more
                if let nextReview = reviewQueue.popFirst() {
                    group.addTask {
                        do {
                            try await self.createReview(
                                restaurantId: nextReview.restaurantId,
                                stars: nextReview.stars,
                                comment: nextReview.comment,
                                imageData: nextReview.imageData
                            )
                            return .success(())
                        } catch {
                            return .failure(error)
                        }
                    }
                }
            }
        }
        
        return (successCount, failures)
    }
    
    /// Creates a test batch of reviews for testing purposes
    /// - Parameters:
    ///   - restaurantId: Target restaurant ID
    ///   - count: Number of test reviews to create (default: 5)
    ///   - maxConcurrent: Maximum concurrent uploads (default: 2)
    /// - Returns: Batch result with success count and errors
    func createTestBatch(restaurantId: String, count: Int = 5, maxConcurrent: Int = 2) async throws -> (success: Int, failures: [Error]) {
        
        let testReviews = (1...count).map { index in
            (
                restaurantId: restaurantId,
                stars: Int.random(in: 1...5),
                comment: "Test review #\(index) - \(["Great food!", "Amazing service!", "Love this place!", "Highly recommended!", "Will come again!"].randomElement() ?? "Good experience")",
                imageData: nil
            )
        }
        
        return try await createReviewsBatch(testReviews, maxConcurrent: maxConcurrent) { completed, total in
            print("Batch progress: \(completed)/\(total)")
        }
    }
}

// MARK: - Array Extension for Queue Operations
extension Array {
    /// Safely removes and returns the first element
    mutating func popFirst() -> Element? {
        guard !isEmpty else { return nil }
        return removeFirst()
    }
}
