//
//  ReviewsDAO.swift
//  SUMAQ
//

import Foundation
import SQLite3

final class ReviewsDAO {
    private let dbProvider: LocalDatabase

    init(dbProvider: LocalDatabase = .shared) {
        self.dbProvider = dbProvider
    }

    func upsert(_ r: ReviewRecord) throws {
        try dbProvider.withConnection { db in
            let sql = """
            INSERT INTO reviews (id, user_id, restaurant_id, stars, comment, image_url, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                user_id = excluded.user_id,
                restaurant_id = excluded.restaurant_id,
                stars = excluded.stars,
                comment = excluded.comment,
                image_url = excluded.image_url,
                created_at = excluded.created_at
            ;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw error(db) }
            defer { sqlite3_finalize(stmt) }

            bindText(stmt, index: 1, r.id)
            bindText(stmt, index: 2, r.userId)
            bindText(stmt, index: 3, r.restaurantId)
            sqlite3_bind_int(stmt, 4, Int32(r.stars))
            bindText(stmt, index: 5, r.comment)
            bindOptionalText(stmt, index: 6, r.imageUrl)
            bindOptionalInt64(stmt, index: 7, r.createdAt?.timeIntervalSince1970)

            guard sqlite3_step(stmt) == SQLITE_DONE else { throw error(db) }
        }
    }

    func listForRestaurant(_ restaurantId: String) throws -> [ReviewRecord] {
        try dbProvider.withConnection { db in
            let sql = """
            SELECT id, user_id, restaurant_id, stars, comment, image_url, created_at
            FROM reviews
            WHERE restaurant_id = ?
            ORDER BY created_at DESC
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw error(db) }
            defer { sqlite3_finalize(stmt) }
            bindText(stmt, index: 1, restaurantId)

            var rows: [ReviewRecord] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                rows.append(ReviewRecord(
                    id: columnText(stmt, 0),
                    userId: columnText(stmt, 1),
                    restaurantId: columnText(stmt, 2),
                    stars: Int(sqlite3_column_int(stmt, 3)),
                    comment: columnText(stmt, 4),
                    imageUrl: columnOptionalText(stmt, 5),
                    createdAt: columnOptionalDate(stmt, 6)
                ))
            }
            return rows
        }
    }

    func listForUser(_ userId: String) throws -> [ReviewRecord] {
        try dbProvider.withConnection { db in
            let sql = """
            SELECT id, user_id, restaurant_id, stars, comment, image_url, created_at
            FROM reviews
            WHERE user_id = ?
            ORDER BY created_at DESC
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw error(db) }
            defer { sqlite3_finalize(stmt) }
            bindText(stmt, index: 1, userId)
            var rows: [ReviewRecord] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                rows.append(ReviewRecord(
                    id: columnText(stmt, 0),
                    userId: columnText(stmt, 1),
                    restaurantId: columnText(stmt, 2),
                    stars: Int(sqlite3_column_int(stmt, 3)),
                    comment: columnText(stmt, 4),
                    imageUrl: columnOptionalText(stmt, 5),
                    createdAt: columnOptionalDate(stmt, 6)
                ))
            }
            return rows
        }
    }
}

// MARK: - SQLite helpers
private func bindText(_ stmt: OpaquePointer?, index: Int32, _ value: String) {
    sqlite3_bind_text(stmt, index, value, -1, SQLITE_TRANSIENT)
}
private func bindOptionalText(_ stmt: OpaquePointer?, index: Int32, _ value: String?) {
    if let v = value { sqlite3_bind_text(stmt, index, v, -1, SQLITE_TRANSIENT) } else { sqlite3_bind_null(stmt, index) }
}
private func bindOptionalInt64(_ stmt: OpaquePointer?, index: Int32, _ seconds: TimeInterval?) {
    if let s = seconds { sqlite3_bind_int64(stmt, index, sqlite3_int64(s)) } else { sqlite3_bind_null(stmt, index) }
}
private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String {
    guard let c = sqlite3_column_text(stmt, index) else { return "" }
    return String(cString: c)
}
private func columnOptionalText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
    return columnText(stmt, index)
}
private func columnOptionalDate(_ stmt: OpaquePointer?, _ index: Int32) -> Date? {
    guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
    let v = sqlite3_column_int64(stmt, index)
    return Date(timeIntervalSince1970: TimeInterval(v))
}
private func error(_ db: OpaquePointer?) -> NSError {
    let msg = String(cString: sqlite3_errmsg(db))
    return NSError(domain: "LocalDatabase", code: 5, userInfo: [NSLocalizedDescriptionKey: msg])
}


