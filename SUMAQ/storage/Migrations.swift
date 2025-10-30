import Foundation
import SQLite3
 
enum Migrations {
    static func migrate(db: OpaquePointer) throws {
        let current = try getUserVersion(db: db)
        var version = current

        if current < 1 {
            try createV1(db: db)
            version = 1
        }

        if version != current {
            try setUserVersion(db: db, version: version)
        }
    }
 
    private static func createV1(db: OpaquePointer) throws {
        let sql = [
            // USERS (alineado a Firestore)
            """
            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                email TEXT NOT NULL,
                role TEXT NOT NULL DEFAULT 'user',
                budget INTEGER,                 -- preferences.budget
                diet TEXT,                      -- preferences.diet
                profile_picture_url TEXT,       -- preferences.profile_picture
                created_at INTEGER,             -- epoch seconds
                updated_at INTEGER              -- epoch seconds
            );
            """,

            // RESTAURANTS (igual que tenías)
            """
            CREATE TABLE IF NOT EXISTS restaurants (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                type_of_food TEXT NOT NULL,
                rating REAL NOT NULL DEFAULT 0,
                offer INTEGER NOT NULL DEFAULT 0,
                address TEXT,
                opening_time INTEGER,
                closing_time INTEGER,
                image_url TEXT,
                lat REAL,
                lon REAL,
                updated_at INTEGER
            );
            """,

            // REVIEWS (igual, con FKs)
            """
            CREATE TABLE IF NOT EXISTS reviews (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                restaurant_id TEXT NOT NULL,
                stars INTEGER NOT NULL,
                comment TEXT NOT NULL,
                image_url TEXT,
                created_at INTEGER,
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY(restaurant_id) REFERENCES restaurants(id) ON DELETE CASCADE
            );
            """,

            // FAVORITES (tabla nueva relacional)
            """
            CREATE TABLE IF NOT EXISTS favorites (
                user_id TEXT NOT NULL,
                restaurant_id TEXT NOT NULL,
                added_at INTEGER, -- epoch seconds (cuando se añadió)
                PRIMARY KEY (user_id, restaurant_id),
                FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY(restaurant_id) REFERENCES restaurants(id) ON DELETE CASCADE
            );
            """,

            // ÍNDICES
            "CREATE INDEX IF NOT EXISTS idx_reviews_user ON reviews(user_id);",
            "CREATE INDEX IF NOT EXISTS idx_reviews_restaurant_created ON reviews(restaurant_id, created_at DESC);",
            "CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id);",
            "CREATE INDEX IF NOT EXISTS idx_favorites_restaurant ON favorites(restaurant_id);"
        ]
 
        for statement in sql { LocalDatabase.exec(db, sql: statement) }
    }
 
    private static func getUserVersion(db: OpaquePointer) throws -> Int {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA user_version;", -1, &stmt, nil) != SQLITE_OK {
            throw error(db)
        }
        defer { sqlite3_finalize(stmt) }
        if sqlite3_step(stmt) == SQLITE_ROW {
            return Int(sqlite3_column_int(stmt, 0))
        }
        return 0
    }
 
    private static func setUserVersion(db: OpaquePointer, version: Int) throws {
        if sqlite3_exec(db, "PRAGMA user_version = \(version);", nil, nil, nil) != SQLITE_OK {
            throw error(db)
        }
    }
 
    private static func error(_ db: OpaquePointer) -> NSError {
        let msg = String(cString: sqlite3_errmsg(db))
        return NSError(domain: "LocalDatabase", code: 2, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}
