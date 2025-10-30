import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class UsersDAO {
    private let dbProvider: LocalDatabase
 
    init(dbProvider: LocalDatabase = .shared) {
        self.dbProvider = dbProvider
    }
 
    func upsert(_ user: UserRecord) throws {
        try dbProvider.withConnection { db in
            let sql = """
            INSERT INTO users (id, name, email, role, budget, diet, profile_picture_url, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                email = excluded.email,
                role = excluded.role,
                budget = excluded.budget,
                diet = excluded.diet,
                profile_picture_url = excluded.profile_picture_url,
                updated_at = excluded.updated_at
            ;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw error(db) }
            defer { sqlite3_finalize(stmt) }

            bindText(stmt, index: 1, user.id)
            bindText(stmt, index: 2, user.name)
            bindText(stmt, index: 3, user.email)
            bindText(stmt, index: 4, user.role)
            bindOptionalInt64(stmt, index: 5, user.budget.map { TimeInterval($0) }) // usamos int64; otra opción: bindInt
            bindOptionalText(stmt, index: 6, user.diet)
            bindOptionalText(stmt, index: 7, user.profilePictureURL)
            bindOptionalInt64(stmt, index: 8, user.createdAt?.timeIntervalSince1970)
            bindOptionalInt64(stmt, index: 9, user.updatedAt?.timeIntervalSince1970)

            guard sqlite3_step(stmt) == SQLITE_DONE else { throw error(db) }
        }
    }
 
    func get(id: String) throws -> UserRecord? {
        try dbProvider.withConnection { db in
            let sql = """
            SELECT id, name, email, role, budget, diet, profile_picture_url, created_at, updated_at
            FROM users WHERE id = ?
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw error(db) }
            defer { sqlite3_finalize(stmt) }
            bindText(stmt, index: 1, id)
            if sqlite3_step(stmt) == SQLITE_ROW {
                return UserRecord(
                    id: columnText(stmt, 0),
                    name: columnText(stmt, 1),
                    email: columnText(stmt, 2),
                    role: columnText(stmt, 3),
                    budget: (sqlite3_column_type(stmt, 4) == SQLITE_NULL) ? nil : Int(sqlite3_column_int64(stmt, 4)),
                    diet: columnOptionalText(stmt, 5),
                    profilePictureURL: columnOptionalText(stmt, 6),
                    createdAt: columnOptionalDate(stmt, 7),
                    updatedAt: columnOptionalDate(stmt, 8)
                )
            }
            return nil
        }
    }
 
    func getMany(ids: [String]) throws -> [UserRecord] {
        guard !ids.isEmpty else { return [] }
        return try dbProvider.withConnection { db in
            let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
            let sql = """
            SELECT id, name, email, role, budget, diet, profile_picture_url, created_at, updated_at
            FROM users
            WHERE id IN (\(placeholders))
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw error(db) }
            defer { sqlite3_finalize(stmt) }
            for (i, id) in ids.enumerated() { bindText(stmt, index: Int32(i + 1), id) }
            var rows: [UserRecord] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                rows.append(UserRecord(
                    id: columnText(stmt, 0),
                    name: columnText(stmt, 1),
                    email: columnText(stmt, 2),
                    role: columnText(stmt, 3),
                    budget: (sqlite3_column_type(stmt, 4) == SQLITE_NULL) ? nil : Int(sqlite3_column_int64(stmt, 4)),
                    diet: columnOptionalText(stmt, 5),
                    profilePictureURL: columnOptionalText(stmt, 6),
                    createdAt: columnOptionalDate(stmt, 7),
                    updatedAt: columnOptionalDate(stmt, 8)
                ))
            }
            return rows
        }
    }
}
 
// MARK: - SQLite helpers (con withCString)
private func bindText(_ stmt: OpaquePointer?, index: Int32, _ value: String) {
    value.withCString { cString in
        sqlite3_bind_text(stmt, index, cString, -1, SQLITE_TRANSIENT)
    }
}
private func bindOptionalText(_ stmt: OpaquePointer?, index: Int32, _ value: String?) {
    if let v = value {
        v.withCString { cString in
            sqlite3_bind_text(stmt, index, cString, -1, SQLITE_TRANSIENT)
        }
    } else { sqlite3_bind_null(stmt, index) }
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
    return NSError(domain: "LocalDatabase", code: 3, userInfo: [NSLocalizedDescriptionKey: msg])
}
