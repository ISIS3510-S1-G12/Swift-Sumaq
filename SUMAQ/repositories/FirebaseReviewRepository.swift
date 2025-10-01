
import FirebaseFirestore
import UIKit

final class FirebaseReviewRepository: ReviewRepository {
    private let db = Firestore.firestore()
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

    // MARK: - Create (miniatura en Firestore, sin Storage)
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

        // Generar miniatura base64 (opcional) para guardar "junto a la review"
        var photoBase64: String? = nil
        if let photo,
           let small = photo.resized(maxSide: 500),                // ~500 px lado mayor
           let jpeg = small.jpegData(compressionQuality: 0.5) {    // calidad moderada
            photoBase64 = jpeg.base64EncodedString()
        }

        // Construir el modelo principal (sin URL de foto)
        let review = Review(
            id: reviewId,
            userId: userId,
            restaurantId: restaurantId,
            authorUsername: authorUsername,
            rating: rating,
            comment: comment,
            createdAt: Date(),
            photoURL: nil,
            photoBase64: photoBase64
        )

        // Armar payload para Firestore
        var data = review.asFirestore
        data["createdAt"] = FieldValue.serverTimestamp()           // fuente de verdad
        if let photoBase64 { data["photoBase64"] = photoBase64 }   // miniatura inline

        try await newRef.setData(data, merge: false)
        return reviewId
    }
}

// MARK: - Helper de imagen (redimensionar)
private extension UIImage {
    /// Redimensiona manteniendo aspecto: el lado mayor queda en `maxSide` (si ya es menor, no cambia).
    func resized(maxSide: CGFloat) -> UIImage? {
        let w = size.width, h = size.height
        let longest = max(w, h)
        guard longest > maxSide, maxSide > 0 else { return self }
        let scale = maxSide / longest
        let newSize = CGSize(width: w * scale, height: h * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
