//
//  LocalFileStore.swift
//  SUMAQ
//
//  Created by Maria Alejandra Pinzon Roncancio on 2/10/25.
//

import Foundation

final class LocalFileStore {
    static let shared = LocalFileStore()
    private init() {}

    @discardableResult
    func save(data: Data, fileName: String, subfolder: String?) throws -> URL {
        let fm = FileManager.default
        let docs = try fm.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)

        let dir = (subfolder?.isEmpty == false) ? docs.appendingPathComponent(subfolder!, isDirectory: true) : docs
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let fileURL = dir.appendingPathComponent(fileName, isDirectory: false)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
