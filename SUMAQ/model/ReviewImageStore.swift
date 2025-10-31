//
//  ReviewImageStore.swift
//  SUMAQ
//
//  Simple local file storage for review images (only current user's reviews)
//  Strategy: Archivos locales (simple)

import Foundation
import FirebaseAuth

final class ReviewImageStore {
    static let shared = ReviewImageStore()
    private init() {}
    
    // Get current user ID
    private func currentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }
    
    // Save review image locally (only for current user)
    func saveImage(data: Data, reviewId: String) throws -> String {
        guard currentUserId() != nil else {
            throw NSError(domain: "ReviewImageStore", code: 401, userInfo: [NSLocalizedDescriptionKey: "No user session"])
        }
        
        let fileName = "\(reviewId).jpg"
        let localURL = try LocalFileStore.shared.save(
            data: data,
            fileName: fileName,
            subfolder: "my_reviews"
        )
        
        return localURL.path
    }
    
    // Get local image path for review (only for current user)
    func getImagePath(reviewId: String) -> String? {
        guard currentUserId() != nil else { return nil }
        
        let fm = FileManager.default
        guard let docsDir = try? fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            return nil
        }
        
        let filePath = docsDir.appendingPathComponent("my_reviews/\(reviewId).jpg").path
        return fm.fileExists(atPath: filePath) ? filePath : nil
    }
    
    // Check if image exists locally
    func hasLocalImage(reviewId: String) -> Bool {
        return getImagePath(reviewId: reviewId) != nil
    }
    
    // Delete local image (cleanup)
    func deleteImage(reviewId: String) {
        guard let path = getImagePath(reviewId: reviewId) else { return }
        try? FileManager.default.removeItem(atPath: path)
    }
}

