//
//  RestaurantsDAO.swift
//  SUMAQ
//

import Foundation
import SQLite3

final class RestaurantsDAO {
    private let dbProvider: LocalDatabase

    init(dbProvider: LocalDatabase = .shared) {
        self.dbProvider = dbProvider
    }

    func upsert(_ r: RestaurantRecord) throws {
        try dbProvider.withConnection { db in
            let sql = """
            INSERT INTO restaurants (id, name, type_of_food, rating, offer, address, opening_time, closing_time, image_url, lat, lon, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                type_of_food = excluded.type_of_food,
                rating = excluded.rating,
                offer = excluded.offer,
                address = excluded.address,
                opening_time = excluded.opening_time,
                closing_time = excluded.closing_time,
                image_url = excluded.image_url,
                lat = excluded.lat,
                lon = excluded.lon,
                updated_at = excluded.updated_at
            ;
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw error(db) }
            defer { sqlite3_finalize(stmt) }

            bindText(stmt, index: 1, r.id)
            bindText(stmt, index: 2, r.name)
            bindText(stmt, index: 3, r.typeOfFood)
            sqlite3_bind_double(stmt, 4, r.rating)
            sqlite3_bind_int(stmt, 5, r.offer ? 1 : 0)
            bindOptionalText(stmt, index: 6, r.address)
            bindOptionalInt(stmt, index: 7, r.openingTime)
            bindOptionalInt(stmt, index: 8, r.closingTime)
            bindOptionalText(stmt, index: 9, r.imageUrl)
            bindOptionalDouble(stmt, index: 10, r.lat)
            bindOptionalDouble(stmt, index: 11, r.lon)
            bindOptionalInt64(stmt, index: 12, r.updatedAt?.timeIntervalSince1970)

            guard sqlite3_step(stmt) == SQLITE_DONE else { throw error(db) }
        }
    }

    func all() throws -> [RestaurantRecord] {
        try dbProvider.withConnection { db in
            let sql = "SELECT id, name, type_of_food, rating, offer, address, opening_time, closing_time, image_url, lat, lon, updated_at FROM restaurants"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw error(db) }
            defer { sqlite3_finalize(stmt) }
            var rows: [RestaurantRecord] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                rows.append(RestaurantRecord(
                    id: columnText(stmt, 0),
                    name: columnText(stmt, 1),
                    typeOfFood: columnText(stmt, 2),
                    rating: sqlite3_column_double(stmt, 3),
                    offer: sqlite3_column_int(stmt, 4) == 1,
                    address: columnOptionalText(stmt, 5),
                    openingTime: columnOptionalInt(stmt, 6),
                    closingTime: columnOptionalInt(stmt, 7),
                    imageUrl: columnOptionalText(stmt, 8),
                    lat: columnOptionalDouble(stmt, 9),
                    lon: columnOptionalDouble(stmt, 10),
                    updatedAt: columnOptionalDate(stmt, 11)
                ))
            }
            return rows
        }
    }

    func getMany(ids: [String]) throws -> [RestaurantRecord] {
        guard !ids.isEmpty else { return [] }
        return try dbProvider.withConnection { db in
            let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
            let sql = "SELECT id, name, type_of_food, rating, offer, address, opening_time, closing_time, image_url, lat, lon, updated_at FROM restaurants WHERE id IN (\(placeholders))"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { throw error(db) }
            defer { sqlite3_finalize(stmt) }
            for (i, id) in ids.enumerated() { bindText(stmt, index: Int32(i + 1), id) }
            var rows: [RestaurantRecord] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                rows.append(RestaurantRecord(
                    id: columnText(stmt, 0),
                    name: columnText(stmt, 1),
                    typeOfFood: columnText(stmt, 2),
                    rating: sqlite3_column_double(stmt, 3),
                    offer: sqlite3_column_int(stmt, 4) == 1,
                    address: columnOptionalText(stmt, 5),
                    openingTime: columnOptionalInt(stmt, 6),
                    closingTime: columnOptionalInt(stmt, 7),
                    imageUrl: columnOptionalText(stmt, 8),
                    lat: columnOptionalDouble(stmt, 9),
                    lon: columnOptionalDouble(stmt, 10),
                    updatedAt: columnOptionalDate(stmt, 11)
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
private func bindOptionalInt(_ stmt: OpaquePointer?, index: Int32, _ value: Int?) {
    if let v = value { sqlite3_bind_int(stmt, index, Int32(v)) } else { sqlite3_bind_null(stmt, index) }
}
private func bindOptionalDouble(_ stmt: OpaquePointer?, index: Int32, _ value: Double?) {
    if let v = value { sqlite3_bind_double(stmt, index, v) } else { sqlite3_bind_null(stmt, index) }
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
private func columnOptionalInt(_ stmt: OpaquePointer?, _ index: Int32) -> Int? {
    guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
    return Int(sqlite3_column_int(stmt, index))
}
private func columnOptionalDouble(_ stmt: OpaquePointer?, _ index: Int32) -> Double? {
    guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
    return sqlite3_column_double(stmt, index)
}
private func columnOptionalDate(_ stmt: OpaquePointer?, _ index: Int32) -> Date? {
    guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
    let v = sqlite3_column_int64(stmt, index)
    return Date(timeIntervalSince1970: TimeInterval(v))
}
private func error(_ db: OpaquePointer?) -> NSError {
    let msg = String(cString: sqlite3_errmsg(db))
    return NSError(domain: "LocalDatabase", code: 4, userInfo: [NSLocalizedDescriptionKey: msg])
}


