import Foundation
import SQLite3

class DatabaseManager {
    static let shared = DatabaseManager()
    private var db: OpaquePointer?
    private let dbPath: String

    private init() {
        let fileManager = FileManager.default
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        dbPath = documentsDir.appendingPathComponent("sticky_notes.sqlite").path

        if !fileManager.fileExists(atPath: dbPath) {
            createDatabase()
        } else {
            openDatabase()
        }
    }

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("DatabaseManager: Error opening database at \(dbPath): \(errmsg)")
        } else {
            print("DatabaseManager: Successfully opened database at \(dbPath)")
        }
    }

    private func createDatabase() {
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            let createTableSQL = """
                CREATE TABLE IF NOT EXISTS notes (
                    id TEXT PRIMARY KEY,
                    text TEXT NOT NULL,
                    createdAt REAL NOT NULL,
                    modifiedAt REAL NOT NULL,
                    color TEXT NOT NULL
                );
            """

            if sqlite3_exec(db, createTableSQL, nil, nil, nil) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("DatabaseManager: Error creating table: \(errmsg)")
            } else {
                print("DatabaseManager: Successfully created database and table at \(dbPath)")
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("DatabaseManager: Error creating database: \(errmsg)")
        }
    }

    func saveNote(note: StickyNote) {
        let sql = """
            INSERT OR REPLACE INTO notes (id, text, createdAt, modifiedAt, color)
            VALUES (?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (note.id.uuidString as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (note.text as NSString).utf8String, -1, nil)
            sqlite3_bind_double(statement, 3, note.createdAt.timeIntervalSince1970)
            sqlite3_bind_double(statement, 4, note.modifiedAt.timeIntervalSince1970)
            sqlite3_bind_text(statement, 5, (note.color.rawValue as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("DatabaseManager: Error saving note \(note.id): \(errmsg)")
            } else {
                print("DatabaseManager: Successfully saved note \(note.id)")
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("DatabaseManager: Error preparing save statement: \(errmsg)")
        }

        sqlite3_finalize(statement)
    }

    func fetchNotes() -> [StickyNote] {
        var notes: [StickyNote] = []
        let sql = "SELECT id, text, createdAt, modifiedAt, color FROM notes ORDER BY modifiedAt DESC;"

        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0))) ?? UUID()
                let text = String(cString: sqlite3_column_text(statement, 1))
                let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
                let modifiedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 3))
                let colorRaw = String(cString: sqlite3_column_text(statement, 4))
                let color = NoteColor(rawValue: colorRaw) ?? .yellow

                var note = StickyNote(id: id, text: text, color: color)
                note.createdAt = createdAt
                note.modifiedAt = modifiedAt
                notes.append(note)
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("DatabaseManager: Error preparing fetch statement: \(errmsg)")
        }

        sqlite3_finalize(statement)
        return notes
    }

    func deleteNote(id: UUID) {
        let sql = "DELETE FROM notes WHERE id = ?;"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (id.uuidString as NSString).utf8String, -1, nil)

            if sqlite3_step(statement) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("DatabaseManager: Error deleting note \(id): \(errmsg)")
            } else {
                print("DatabaseManager: Successfully deleted note \(id)")
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("DatabaseManager: Error preparing delete statement: \(errmsg)")
        }

        sqlite3_finalize(statement)
    }
}
