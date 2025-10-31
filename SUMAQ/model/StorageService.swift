//
//  StorageService.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//

import Foundation
import FirebaseStorage
import FirebaseAuth

final class StorageService {
    static let shared = StorageService()
    private init() {}

    private let storage = Storage.storage()

    func uploadImageData(_ data: Data,
                         to path: String,
                         contentType: String? = nil,
                         progress: ((Double) -> Void)? = nil,
                         completion: @escaping (Result<String, Error>) -> Void) {
        // Ensure user is authenticated before uploading
        guard let user = Auth.auth().currentUser else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "Storage", code: 401,
                                              userInfo: [NSLocalizedDescriptionKey: "User not authenticated. Please log in again."])))
            }
            return
        }
        
        // Refresh auth token to ensure it's valid for Storage operations
        // This is critical after offline login or when coming back online
        Task {
            do {
                // Try to get a fresh token (this will refresh if needed)
                let token = try await user.getIDToken(forcingRefresh: false)
                print("✅ Auth token retrieved successfully for user: \(user.uid)")
                print("✅ Token length: \(token.count) characters")
                
                // Token is valid - proceed with upload on main thread
                await MainActor.run {
                    self.performUpload(data: data, path: path, contentType: contentType, progress: progress, completion: completion)
                }
            } catch {
                print("⚠️ Token refresh failed, trying forced refresh: \(error.localizedDescription)")
                // Token refresh failed - try forcing a refresh
                do {
                    let token = try await user.getIDToken(forcingRefresh: true)
                    print("✅ Auth token force-refreshed successfully for user: \(user.uid)")
                    print("✅ Token length: \(token.count) characters")
                    
                    // Token refreshed successfully - proceed with upload
                    await MainActor.run {
                        self.performUpload(data: data, path: path, contentType: contentType, progress: progress, completion: completion)
                    }
                } catch {
                    // Even forced refresh failed - authentication is not valid
                    print("❌ Token refresh completely failed: \(error.localizedDescription)")
                    await MainActor.run {
                        completion(.failure(NSError(domain: "Storage", code: 401,
                                                   userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please log in again."])))
                    }
                }
            }
        }
    }
    
    private func performUpload(data: Data,
                               path: String,
                               contentType: String?,
                               progress: ((Double) -> Void)?,
                               completion: @escaping (Result<String, Error>) -> Void) {
        // Double-check authentication before creating reference
        guard let user = Auth.auth().currentUser else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "Storage", code: 401,
                                              userInfo: [NSLocalizedDescriptionKey: "User not authenticated. Please log in again."])))
            }
            return
        }
        
        // Create Storage reference
        let ref = storage.reference(withPath: path)
        let md = StorageMetadata()
        md.contentType = contentType ?? "image/jpeg"
        
        // Add custom metadata to ensure auth is associated with the upload
        // Store the user ID in metadata for debugging
        md.customMetadata = ["uploadedBy": user.uid]

        let task = ref.putData(data, metadata: md) { metadata, err in
            // Ensure completion handler runs on main thread
            if let err { 
                // Log detailed error information for debugging
                let nsError = err as NSError
                print("❌ Storage upload error - Domain: \(nsError.domain), Code: \(nsError.code)")
                print("❌ Error description: \(err.localizedDescription)")
                print("❌ User ID: \(user.uid)")
                print("❌ User email: \(user.email ?? "no email")")
                print("❌ Path: \(path)")
                
                // Provide more helpful error messages for permission errors
                DispatchQueue.main.async {
                    if nsError.domain == "FIRStorageErrorDomain" {
                        switch nsError.code {
                        case -13021: // Unauthorized
                            completion(.failure(NSError(domain: "Storage", code: 401,
                                                           userInfo: [NSLocalizedDescriptionKey: "Permission denied. User ID: \(user.uid). Please ensure Firebase Storage rules allow authenticated users to write."])))
                        case -13020: // Object not found (but in this context might be permission)
                            completion(.failure(NSError(domain: "Storage", code: 403,
                                                           userInfo: [NSLocalizedDescriptionKey: "Permission denied. Please check your authentication status and Firebase Storage rules."])))
                        default:
                            completion(.failure(err))
                        }
                    } else {
                        completion(.failure(err))
                    }
                }
                return
            }
            ref.downloadURL { url, err in
                // Ensure completion handler runs on main thread
                DispatchQueue.main.async {
                    if let err { 
                        print("❌ Error getting download URL: \(err.localizedDescription)")
                        completion(.failure(err)) 
                    }
                    else if let url { 
                        print("✅ Upload successful! URL: \(url.absoluteString)")
                        completion(.success(url.absoluteString)) 
                    }
                    else { 
                        completion(.failure(NSError(domain: "Storage", code: -3,
                                                       userInfo: [NSLocalizedDescriptionKey:"No URL"])) ) 
                    }
                }
            }
        }
        
        if let progress {
            task.observe(.progress) { snapshot in
                guard let total = snapshot.progress?.totalUnitCount,
                      total > 0,
                      let completed = snapshot.progress?.completedUnitCount else { return }
                let pct = Double(completed) / Double(total)
                // Ensure progress callback runs on main thread
                DispatchQueue.main.async {
                    progress(pct)
                }
            }
        }
    }

    func copyRemoteImageToStorage(from urlString: String,
                                  to path: String,
                                  completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            return completion(.failure(NSError(domain: "Storage",
                                               code: 400,
                                               userInfo: [NSLocalizedDescriptionKey: "URL inválida"])))
        }
        URLSession.shared.dataTask(with: url) { data, _, err in
            if let err { return completion(.failure(err)) }
            guard let data else {
                return completion(.failure(NSError(domain: "Storage",
                                                   code: 404,
                                                   userInfo: [NSLocalizedDescriptionKey: "Sin datos de imagen"])) )
            }
            let ext = url.pathExtension.lowercased()
            let type = (ext == "png") ? "image/png" : "image/jpeg"
            self.uploadImageData(data, to: path, contentType: type, progress: nil, completion: completion)
        }.resume()
    }
}
