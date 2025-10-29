//
//  LocalDatabase.swift
//  SUMAQ
//

import Foundation
import SQLite3

final class LocalDatabase {
    static let shared = LocalDatabase()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "localdb.sqlite.queue", qos: .userInitiated)

    private init() {}

    // MARK: - Public accessors
    func withConnection<T>(_ body: (OpaquePointer) throws -> T) rethrows -> T {
        guard let db = db else {
            fatalError("LocalDatabase not initialized. Call configure() early in app lifecycle.")
        }
        return try body(db)
    }

    // MARK: - Setup
    func configure() throws {
        if db != nil { return }
        let url = try Self.databaseURL()

        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &handle, flags, nil) != SQLITE_OK {
            let msg = String(cString: sqlite3_errmsg(handle))
            throw NSError(domain: "LocalDatabase", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open DB: \(msg)"])
        }

        // Pragmas for reliability and performance
        _ = Self.exec(handle, sql: "PRAGMA foreign_keys = ON;")
        _ = Self.exec(handle, sql: "PRAGMA journal_mode = WAL;")
        _ = Self.exec(handle, sql: "PRAGMA synchronous = NORMAL;")

        self.db = handle
        try Migrations.migrate(db: handle!)
    }

    // MARK: - Utilities
    private static func databaseURL() throws -> URL {
        let base = try FileManager.default.url(for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("LocalDatabase", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("sumaq.sqlite")
    }

    @discardableResult
    static func exec(_ db: OpaquePointer?, sql: String) -> Int32 {
        var err: UnsafeMutablePointer<Int8>? = nil
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK, let err = err {
            let msg = String(cString: err)
            print("SQLite exec error: \(msg) for SQL: \(sql)")
            sqlite3_free(err)
        }
        return rc
    }
}


