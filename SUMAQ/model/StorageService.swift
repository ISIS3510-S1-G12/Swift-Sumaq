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
            return completion(.failure(NSError(domain: "Storage", code: 401,
                                              userInfo: [NSLocalizedDescriptionKey: "User not authenticated. Please log in again."])))
        }
        
        // Refresh auth token to ensure it's valid for Storage operations
        // This is critical after offline login or when coming back online
        Task {
            do {
                // Try to get a fresh token (this will refresh if needed)
                let _ = try await user.getIDToken(forcingRefresh: false)
                // Token is valid - proceed with upload on main thread
                await MainActor.run {
                    self.performUpload(data: data, path: path, contentType: contentType, progress: progress, completion: completion)
                }
            } catch {
                // Token refresh failed - try forcing a refresh
                do {
                    let _ = try await user.getIDToken(forcingRefresh: true)
                    // Token refreshed successfully - proceed with upload
                    await MainActor.run {
                        self.performUpload(data: data, path: path, contentType: contentType, progress: progress, completion: completion)
                    }
                } catch {
                    // Even forced refresh failed - authentication is not valid
                    completion(.failure(NSError(domain: "Storage", code: 401,
                                               userInfo: [NSLocalizedDescriptionKey: "Authentication failed. Please log in again."])))
                }
            }
        }
    }
    
    private func performUpload(data: Data,
                               path: String,
                               contentType: String?,
                               progress: ((Double) -> Void)?,
                               completion: @escaping (Result<String, Error>) -> Void) {
        let ref = storage.reference(withPath: path)
        let md = StorageMetadata()
        md.contentType = contentType ?? "image/jpeg"

        let task = ref.putData(data, metadata: md) { _, err in
            if let err { 
                // Provide more helpful error messages for permission errors
                let nsError = err as NSError
                if nsError.domain == "FIRStorageErrorDomain" {
                    switch nsError.code {
                    case -13021: // Unauthorized
                        return completion(.failure(NSError(domain: "Storage", code: 401,
                                                           userInfo: [NSLocalizedDescriptionKey: "Permission denied. Please ensure you are logged in and try again."])))
                    case -13020: // Object not found (but in this context might be permission)
                        return completion(.failure(NSError(domain: "Storage", code: 403,
                                                           userInfo: [NSLocalizedDescriptionKey: "Permission denied. Please check your authentication status."])))
                    default:
                        return completion(.failure(err))
                    }
                }
                return completion(.failure(err)) 
            }
            ref.downloadURL { url, err in
                if let err { completion(.failure(err)) }
                else if let url { completion(.success(url.absoluteString)) }
                else { completion(.failure(NSError(domain: "Storage", code: -3,
                                                   userInfo: [NSLocalizedDescriptionKey:"No URL"])) ) }
            }
        }
        
        if let progress {
            task.observe(.progress) { snapshot in
                guard let total = snapshot.progress?.totalUnitCount,
                      total > 0,
                      let completed = snapshot.progress?.completedUnitCount else { return }
                let pct = Double(completed) / Double(total)
                progress(pct)
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
