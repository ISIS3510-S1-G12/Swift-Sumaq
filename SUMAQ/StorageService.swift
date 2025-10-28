//
//  StorageService.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//

import Foundation
import FirebaseStorage

final class StorageService {
    static let shared = StorageService()
    private init() {}

    private let storage = Storage.storage()

    func uploadImageData(_ data: Data,
                         to path: String,
                         contentType: String? = nil,
                         progress: ((Double) -> Void)? = nil,
                         completion: @escaping (Result<String, Error>) -> Void) {
        let ref = storage.reference(withPath: path)
        let md = StorageMetadata()
        md.contentType = contentType ?? "image/jpeg"

        let task = ref.putData(data, metadata: md) { _, err in
            if let err { return completion(.failure(err)) }
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
