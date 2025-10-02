//
//  ReviewsRepository.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 30/09/25.
//
// ReviewsRepository.swift
// SUMAQ

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
                      imageData: Data?) async throws {
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

            //  Subir a Storage y escribir downloadURL
            let path = "reviews/\(uid)/\(ref.documentID).jpg"
            let urlString = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                StorageService.shared.uploadImageData(data, to: path, contentType: "image/jpeg") { res in
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

    func listForRestaurant(_ restaurantId: String) async throws -> [Review] {
        let qs = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<QuerySnapshot, Error>) in
            db.collection(coll)
                .whereField("restaurant_id", isEqualTo: restaurantId)
                .getDocuments { qs, err in
                    if let err { cont.resume(throwing: err) }
                    else if let qs { cont.resume(returning: qs) }
                    else { cont.resume(throwing: NSError(domain: "Firestore", code: -1)) }
                }
        }
        return qs.documents.compactMap { Review(doc: $0) }
    }
}
