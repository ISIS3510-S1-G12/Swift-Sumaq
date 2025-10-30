//
//  FavoritesLocalStorage.swift
//  SUMAQ
//
//  Created by Gabriela  Escobar Rojas on 29/10/25.
//


import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class FavoritesDAO {
    private let dbProvider: LocalDatabase
 
    init(dbProvider: LocalDatabase = .shared) {
        self.dbProvider = dbProvider
    }

    // Insertar o reemplazar favorito
    func upsert(_ fav: FavoriteRecord) throws {
        try dbProvider.withConnection { db in
            let sql = """
            INSERT OR REPLACE INTO favorites (user_id, restaurant_id, added_at)
            VALUES (?, ?, ?);
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw error(db) }
            defer { sqlite3_finalize(stmt) }

            bindText(stmt, index: 1, fav.userId)
            bindText(stmt, index: 2, fav.restaurantId)
            bindOptionalInt64(stmt, index: 3, fav.addedAt?.timeIntervalSince1970)

            guard sqlite3_step(stmt) == SQLITE_DONE else { throw error(db) }
        }
    }

    // Eliminar favorito
    func remove(userId: String, restaurantId: String) throws {
        try dbProvider.withConnection { db in
            let sql = "DELETE FROM favorites WHERE user_id = ? AND restaurant_id = ?"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw error(db) }
            defer { sqlite3_finalize(stmt) }
            bindText(stmt, index: 1, userId)
            bindText(stmt, index: 2, restaurantId)
            guard sqlite3_step(stmt) == SQLITE_DONE else { throw error(db) }
        }
    }

    // Listar IDs de restaurantes favoritos de un usuario (ordenados por fecha desc)
    func listRestaurantIds(for userId: String) throws -> [String] {
        try dbProvider.withConnection { db in
            let sql = """
            SELECT restaurant_id
            FROM favorites
            WHERE user_id = ?
            ORDER BY added_at DESC
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw error(db) }
            defer { sqlite3_finalize(stmt) }
            bindText(stmt, index: 1, userId)

            var rows: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                rows.append(columnText(stmt, 0))
            }
            return rows
        }
    }
}

// MARK: - SQLite helpers
private func bindText(_ stmt: OpaquePointer?, index: Int32, _ value: String) {
    value.withCString { cString in
        sqlite3_bind_text(stmt, index, cString, -1, SQLITE_TRANSIENT)
    }
}
private func bindOptionalInt64(_ stmt: OpaquePointer?, index: Int32, _ seconds: TimeInterval?) {
    if let s = seconds { sqlite3_bind_int64(stmt, index, sqlite3_int64(s)) } else { sqlite3_bind_null(stmt, index) }
}
private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String {
    guard let c = sqlite3_column_text(stmt, index) else { return "" }
    return String(cString: c)
}
private func error(_ db: OpaquePointer?) -> NSError {
    let msg = String(cString: sqlite3_errmsg(db))
    return NSError(domain: "LocalDatabase", code: 6, userInfo: [NSLocalizedDescriptionKey: msg])
}
