//
//  ReviewsRepository.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

final class ReviewsRepository {
    private let db = Firestore.firestore()
    private let coll = "Reviews"
    private let local = LocalStore.shared   // acceso a SQLite para offline

    private func currentUid() throws -> String {
        if let uid = Auth.auth().currentUser?.uid { return uid }
        throw NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No session"])
    }
    
    // MARK: - Helper: Convert ReviewRecord to Review domain model
    private func toReview(from record: ReviewRecord) -> Review {
        return Review(
            id: record.id,
            userId: record.userId,
            restaurantId: record.restaurantId,
            stars: record.stars,
            comment: record.comment,
            imageURL: record.imageUrl,
            createdAt: record.createdAt
        )
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
            // Save image locally for offline access (simple file storage)
            do {
                _ = try ReviewImageStore.shared.saveImage(data: data, reviewId: ref.documentID)
            } catch {
                // Non-fatal: continue even if local save fails
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
                    // Save review to SQLite for offline access
                    // Image was already saved locally above when uploading
                    Task.detached(priority: .utility) { [local = self.local, ref] in
                        do {
                            // Get the created review from Firestore to save locally
                            if let doc = try? await self.db.collection(self.coll).document(ref.documentID).getDocument(),
                               let review = Review(doc: doc) {
                                try? local.reviews.upsert(ReviewRecord(from: review))
                            }
                        } catch {
                            // Non-fatal: cache write failure is ignored
                        }
                    }
                    
                    NotificationCenter.default.post(name: .userReviewsDidChange, object: nil)
                    NotificationCenter.default.post(name: .reviewDidCreate, object: nil)
                    cont.resume(returning: ())
                }
            }
        }
    }

    func listMyReviews() async throws -> [Review] {
        let uid = try currentUid()
        
        // Offline-first: Try to read from SQLite first (fast, no loading)
        let localRecords = (try? local.reviews.listForUser(uid)) ?? []
        
        if !localRecords.isEmpty {
            // We have local data, return it immediately
            // and refresh from Firestore in background
            Task.detached { [weak self] in
                guard let self else { return }
                do {
                    let qs = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<QuerySnapshot, Error>) in
                        self.db.collection(self.coll)
                            .whereField("user_id", isEqualTo: uid)
                            .getDocuments { qs, err in
                                if let err { cont.resume(throwing: err) }
                                else if let qs { cont.resume(returning: qs) }
                                else { cont.resume(throwing: NSError(domain: "Firestore", code: -1)) }
                            }
                    }
                    
                    let items = qs.documents.compactMap { Review(doc: $0) }
                    
                    // Save to SQLite in background
                    // Also save images locally for current user's reviews
                    for review in items {
                        try? self.local.reviews.upsert(ReviewRecord(from: review))
                        
                        // Save image locally if it's the current user's review
                        if let imageURL = review.imageURL {
                            await self.saveImageLocallyIfMine(imageURL: imageURL, reviewId: review.id, reviewUserId: review.userId)
                        }
                    }
                    
                    // Notify view to refresh if needed
                    NotificationCenter.default.post(name: .userReviewsDidChange, object: nil)
                } catch {
                    // Background refresh failure is non-fatal
                }
            }
            
            // Return local data immediately
            return localRecords.map { toReview(from: $0) }
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        }
        
        // No local data: fetch from Firestore
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
        let sortedItems = items.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        
        // Save to SQLite for next time (best-effort, non-blocking)
        // Also save images locally for current user's reviews
        Task.detached(priority: .utility) { [weak self, local = self.local] in
            guard let self else { return }
            for review in sortedItems {
                try? local.reviews.upsert(ReviewRecord(from: review))
                
                // Save image locally if it's the current user's review
                if let imageURL = review.imageURL {
                    await self.saveImageLocallyIfMine(imageURL: imageURL, reviewId: review.id, reviewUserId: review.userId)
                }
            }
        }
        
        return sortedItems
    }

    func listForRestaurant(restaurantId: String) async throws -> [Review] {
        // Offline-first: Try to read from SQLite first (fast, no loading)
        let localRecords = (try? local.reviews.listForRestaurant(restaurantId)) ?? []
        
        if !localRecords.isEmpty {
            // We have local data, return it immediately
            // and refresh from Firestore in background
            Task.detached { [weak self] in
                guard let self else { return }
                do {
                    let qs = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<QuerySnapshot, Error>) in
                        self.db.collection(self.coll)
                            .whereField("restaurant_id", isEqualTo: restaurantId)
                            .getDocuments { qs, err in
                                if let err { cont.resume(throwing: err) }
                                else if let qs { cont.resume(returning: qs) }
                                else { cont.resume(throwing: NSError(domain: "Firestore", code: -1)) }
                            }
                    }
                    
                    let items = qs.documents.compactMap { Review(doc: $0) }
                    
                    // Save to SQLite in background
                    for review in items {
                        try? self.local.reviews.upsert(ReviewRecord(from: review))
                    }
                    
                    // Notify view to refresh if needed
                    NotificationCenter.default.post(name: .userReviewsDidChange, object: nil)
                } catch {
                    // Background refresh failure is non-fatal
                }
            }
            
            // Return local data immediately
            return localRecords.map { toReview(from: $0) }
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        }
        
        // No local data or online-first: fetch from Firestore
        // Online-first with offline fallback (similar to restaurants in HomeUserView)
        do {
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
            let sortedItems = items.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            
            // Save to SQLite in background (best-effort, non-blocking)
            Task.detached(priority: .utility) { [local = self.local] in
                for review in sortedItems {
                    try? local.reviews.upsert(ReviewRecord(from: review))
                }
            }
            
            return sortedItems
        } catch {
            // Fallback to offline: read from SQLite if remote fails
            let fallbackRecords = (try? local.reviews.listForRestaurant(restaurantId)) ?? []
            return fallbackRecords.map { toReview(from: $0) }
                .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        }
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
                imageData: nil as Data?
            )
        }
        
        return try await createReviewsBatch(testReviews, maxConcurrent: maxConcurrent) { completed, total in
            print("Batch progress: \(completed)/\(total)")
        }
    }
}

// MARK: - Combine Publishers
extension ReviewsRepository {
    
    /// Returns a publisher that emits review updates for a restaurant in real-time
    /// - Parameter restaurantId: The restaurant to listen for reviews
    /// - Returns: Publisher emitting arrays of reviews
    func reviewsPublisher(for restaurantId: String) -> AnyPublisher<[Review], Error> {
        Future { [weak self] promise in
            guard let self = self else {
                return promise(.failure(NSError(domain: "ReviewsRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Repository deallocated"])))
            }
            
            self.db.collection(self.coll)
                .whereField("restaurant_id", isEqualTo: restaurantId)
                .order(by: "createdAt", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        promise(.failure(error))
                    } else if let snapshot = snapshot {
                        let items = snapshot.documents.compactMap { Review(doc: $0) }
                        promise(.success(items))
                    }
                }
        }
        .eraseToAnyPublisher()
    }
    
    /// Returns a publisher for the current user's reviews in real-time
    /// - Returns: Publisher emitting arrays of reviews
    func myReviewsPublisher() -> AnyPublisher<[Review], Error> {
        Future { [weak self] promise in
            guard let self = self else {
                return promise(.failure(NSError(domain: "ReviewsRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Repository deallocated"])))
            }
            
            do {
                let uid = try self.currentUid()
                self.db.collection(self.coll)
                    .whereField("user_id", isEqualTo: uid)
                    .order(by: "createdAt", descending: true)
                    .addSnapshotListener { snapshot, error in
                        if let error = error {
                            promise(.failure(error))
                        } else if let snapshot = snapshot {
                            let items = snapshot.documents.compactMap { Review(doc: $0) }
                            promise(.success(items))
                        }
                    }
            } catch {
                promise(.failure(error))
            }
        }
        .eraseToAnyPublisher()
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
