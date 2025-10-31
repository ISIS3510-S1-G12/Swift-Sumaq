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
        // Verify user is authenticated before attempting upload
        guard Auth.auth().currentUser != nil else {
            return completion(.failure(NSError(domain: "Storage", code: 401,
                                               userInfo: [NSLocalizedDescriptionKey: "User must be authenticated to upload images"])))
        }
        
        let ref = storage.reference(withPath: path)
        let md = StorageMetadata()
        md.contentType = contentType ?? "image/jpeg"
        
        // Set custom metadata to help with Storage rules
        md.customMetadata = ["uploadedBy": Auth.auth().currentUser?.uid ?? "unknown"]

        let task = ref.putData(data, metadata: md) { metadata, err in
            if let err {
                // Improve error message for permission issues
                let errorCode = (err as NSError).code
                let errorDomain = (err as NSError).domain
                
                if errorDomain.contains("FIRStorageErrorDomain") || errorDomain.contains("Storage") {
                    if errorCode == 13020 || errorCode == -13020 { // Permission denied
                        let improvedError = NSError(domain: "Storage", code: errorCode,
                                                    userInfo: [NSLocalizedDescriptionKey: "No tienes permisos para subir imágenes. Verifica que las reglas de Firebase Storage permitan que usuarios autenticados escriban en la ruta 'reviews/'. Error: \(err.localizedDescription)"])
                        return completion(.failure(improvedError))
                    }
                }
                return completion(.failure(err))
            }
            
            // Get download URL after successful upload
            ref.downloadURL { url, err in
                if let err {
                    // Improve error message for permission issues when getting download URL
                    let errorCode = (err as NSError).code
                    let errorDomain = (err as NSError).domain
                    
                    if errorDomain.contains("FIRStorageErrorDomain") || errorDomain.contains("Storage") {
                        if errorCode == 13020 || errorCode == -13020 { // Permission denied
                            let improvedError = NSError(domain: "Storage", code: errorCode,
                                                        userInfo: [NSLocalizedDescriptionKey: "No tienes permisos para leer la imagen subida. Verifica que las reglas de Firebase Storage permitan lectura para usuarios autenticados. Error: \(err.localizedDescription)"])
                            return completion(.failure(improvedError))
                        }
                    }
                    return completion(.failure(err))
                }
                
                if let url {
                    completion(.success(url.absoluteString))
                } else {
                    completion(.failure(NSError(domain: "Storage", code: -3,
                                               userInfo: [NSLocalizedDescriptionKey: "No se pudo obtener la URL de descarga de la imagen"])))
                }
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
