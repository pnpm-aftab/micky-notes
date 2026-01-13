import Foundation
import SQLite3

enum DatabaseError: Error, LocalizedError {
    case openFailed(String)
    case createFailed(String)
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case transactionFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let msg), .createFailed(let msg),
             .saveFailed(let msg), .fetchFailed(let msg),
             .deleteFailed(let msg), .transactionFailed(let msg):
            return msg
        }
    }
}

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    private let dbPath: String
    private let queue = DispatchQueue(label: "com.stickynotes.database", qos: .userInitiated)

    private init() {
        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        dbPath = documentsDir.appendingPathComponent("sticky_notes.sqlite").path

        // Always open the database first (creates file if needed)
        openDatabase()

        // Create table if it doesn't exist
        createTable()

        // Attempt migration to rich text if needed
        try? migrateToRichText()
    }

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("DatabaseManager: Error opening database at \(dbPath): \(errmsg)")
        } else {
            print("DatabaseManager: Successfully opened database at \(dbPath)")
        }
    }

    private func createTable() {
        let createTableSQL = """
            CREATE TABLE IF NOT EXISTS notes (
                id TEXT PRIMARY KEY,
                attributedText BLOB NOT NULL,
                createdAt REAL NOT NULL,
                modifiedAt REAL NOT NULL,
                color TEXT NOT NULL
            );
        """

        if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("DatabaseManager: Error creating table: \(errmsg)")
        } else {
            print("DatabaseManager: Successfully created table at \(dbPath)")
        }
    }

    private func beginTransaction() throws {
        let sql = "BEGIN TRANSACTION;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw DatabaseError.transactionFailed("Failed to begin transaction: \(errmsg)")
        }

        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw DatabaseError.transactionFailed("Failed to begin transaction: \(errmsg)")
        }
    }

    private func commitTransaction() throws {
        let sql = "COMMIT;";
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw DatabaseError.transactionFailed("Failed to commit transaction: \(errmsg)")
        }

        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            throw DatabaseError.transactionFailed("Failed to commit transaction: \(errmsg)")
        }
    }

    private func rollbackTransaction() {
        let sql = "ROLLBACK;";
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }

    func saveNote(note: StickyNote) throws {
        try queue.sync {
            try beginTransaction()

            let sql = """
                INSERT OR REPLACE INTO notes (id, attributedText, createdAt, modifiedAt, color)
                VALUES (?, ?, ?, ?, ?);
            """

            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                rollbackTransaction()
                throw DatabaseError.saveFailed("Error preparing save statement: \(errmsg)")
            }

            defer { sqlite3_finalize(statement) }

            // Bind ID
            sqlite3_bind_text(statement, 1, (note.id.uuidString as NSString).utf8String, -1, nil)

            // Bind BLOB data (handle empty data)
            if note.attributedText.isEmpty {
                sqlite3_bind_blob(statement, 2, nil, 0, nil)
            } else {
                note.attributedText.withUnsafeBytes { bytes in
                    sqlite3_bind_blob(statement, 2, bytes.baseAddress, Int32(note.attributedText.count), nil)
                }
            }

            // Bind dates and color
            sqlite3_bind_double(statement, 3, note.createdAt.timeIntervalSince1970)
            sqlite3_bind_double(statement, 4, note.modifiedAt.timeIntervalSince1970)
            sqlite3_bind_text(statement, 5, (note.color.rawValue as NSString).utf8String, -1, nil)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                rollbackTransaction()
                throw DatabaseError.saveFailed("Error saving note \(note.id): \(errmsg)")
            }

            try commitTransaction()
            print("DatabaseManager: Successfully saved note \(note.id)")
        }
    }

    func fetchNotes() throws -> [StickyNote] {
        return try queue.sync {
            var notes: [StickyNote] = []
            let sql = "SELECT id, attributedText, createdAt, modifiedAt, color FROM notes ORDER BY modifiedAt DESC;"

            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                throw DatabaseError.fetchFailed("Error preparing fetch statement: \(errmsg)")
            }

            defer { sqlite3_finalize(statement) }

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let idPtr = sqlite3_column_text(statement, 0) else {
                    print("DatabaseManager: Skipping note with nil UUID")
                    continue
                }

                let idString = String(cString: idPtr)
                guard let id = UUID(uuidString: idString) else {
                    print("DatabaseManager: Skipping note with invalid UUID: \(idString)")
                    continue
                }

                // Extract BLOB data
                let blobLength = sqlite3_column_bytes(statement, 1)
                let blobPtr = sqlite3_column_blob(statement, 1)

                // Handle empty BLOB or null BLOB
                let attributedText: Data
                if blobPtr == nil || blobLength == 0 {
                    attributedText = Data()
                } else {
                    attributedText = Data(bytes: blobPtr!, count: Int(blobLength))
                }

                let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
                let modifiedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))

                guard let colorPtr = sqlite3_column_text(statement, 4) else {
                    print("DatabaseManager: Skipping note with nil color")
                    continue
                }
                let colorRaw = String(cString: colorPtr)
                let color = NoteColor(rawValue: colorRaw) ?? .yellow

                var note = StickyNote(id: id, attributedText: attributedText, color: color)
                note.createdAt = createdAt
                note.modifiedAt = modifiedAt
                notes.append(note)
            }

            print("DatabaseManager: Fetched \(notes.count) notes")
            return notes
        }
    }

    func deleteNote(id: UUID) throws {
        try queue.sync {
            try beginTransaction()

            let sql = "DELETE FROM notes WHERE id = ?;"
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                rollbackTransaction()
                throw DatabaseError.deleteFailed("Error preparing delete statement: \(errmsg)")
            }

            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, nil)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                rollbackTransaction()
                throw DatabaseError.deleteFailed("Error deleting note \(id): \(errmsg)")
            }

            try commitTransaction()
            print("DatabaseManager: Successfully deleted note \(id)")
        }
    }

    // MARK: - Migration

    private func migrateToRichText() throws {
        // Check if migration needed by checking column names
        let checkSQL = "PRAGMA table_info(notes);"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, checkSQL, -1, &statement, nil) == SQLITE_OK else {
            return
        }

        var hasAttributedTextColumn = false
        var hasTextColumn = false

        while sqlite3_step(statement) == SQLITE_ROW {
            let columnName = String(cString: sqlite3_column_text(statement, 1))
            if columnName == "attributedText" {
                hasAttributedTextColumn = true
            } else if columnName == "text" {
                hasTextColumn = true
            }
        }
        sqlite3_finalize(statement)

        // Already migrated or no migration needed
        if hasAttributedTextColumn || !hasTextColumn {
            return
        }

        print("DatabaseManager: Starting migration to rich text...")

        // Back up existing notes using old schema
        let tempSQL = "SELECT id, text, createdAt, modifiedAt, color FROM notes;"
        var tempStmt: OpaquePointer?
        var oldNotes: [(id: UUID, text: String, createdAt: Date, modifiedAt: Date, color: NoteColor)] = []

        guard sqlite3_prepare_v2(db, tempSQL, -1, &tempStmt, nil) == SQLITE_OK else {
            print("DatabaseManager: Could not prepare migration query")
            return
        }

        while sqlite3_step(tempStmt) == SQLITE_ROW {
            guard let idPtr = sqlite3_column_text(tempStmt, 0),
                  let id = UUID(uuidString: String(cString: idPtr)),
                  let textPtr = sqlite3_column_text(tempStmt, 1),
                  let colorPtr = sqlite3_column_text(tempStmt, 4) else {
                continue
            }

            let text = String(cString: textPtr)
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(tempStmt, 2))
            let modifiedAt = Date(timeIntervalSince1970: sqlite3_column_double(tempStmt, 3))
            let colorRaw = String(cString: colorPtr)
            let color = NoteColor(rawValue: colorRaw) ?? .yellow

            oldNotes.append((id, text, createdAt, modifiedAt, color))
        }
        sqlite3_finalize(tempStmt)

        // Drop old table and create new one
        try beginTransaction()

        let dropSQL = "DROP TABLE IF EXISTS notes;"
        guard sqlite3_exec(db, dropSQL, nil, nil, nil) == SQLITE_OK else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            rollbackTransaction()
            print("DatabaseManager: Failed to drop old table: \(errmsg)")
            return
        }

        // Create new table with BLOB column
        createTable()

        // Migrate notes: convert plain text to attributed text
        for oldNote in oldNotes {
            let attrString = NSAttributedString(string: oldNote.text)
            let data = StickyNote.encodeAttributedString(attrString)
            var note = StickyNote(id: oldNote.id, attributedText: data, color: oldNote.color)
            note.createdAt = oldNote.createdAt
            note.modifiedAt = oldNote.modifiedAt

            let sql = """
                INSERT INTO notes (id, attributedText, createdAt, modifiedAt, color)
                VALUES (?, ?, ?, ?, ?);
            """

            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                continue
            }

            sqlite3_bind_text(stmt, 1, (note.id.uuidString as NSString).utf8String, -1, nil)
            data.withUnsafeBytes { bytes in
                sqlite3_bind_blob(stmt, 2, bytes.baseAddress, Int32(data.count), nil)
            }
            sqlite3_bind_double(stmt, 3, note.createdAt.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 4, note.modifiedAt.timeIntervalSince1970)
            sqlite3_bind_text(stmt, 5, (note.color.rawValue as NSString).utf8String, -1, nil)

            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }

        try commitTransaction()
        print("DatabaseManager: Successfully migrated \(oldNotes.count) notes to rich text format")
    }
}
