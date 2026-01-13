import Foundation
import SQLite3

class WindowsNotesParser {

    /// Converts Windows FileTime (100-nanosecond intervals since Jan 1, 1601) to Date
    private static func fileTimeToDate(_ fileTime: UInt64) -> Date {
        // Windows FileTime epoch is January 1, 1601 (UTC)
        // Unix epoch is January 1, 1970 (UTC)
        // Difference is 11,644,473,600 seconds
        let windowsEpoch: TimeInterval = 11_644_473_600
        let nanosecondsPerSecond: TimeInterval = 10_000_000
        let secondsSinceWindowsEpoch = TimeInterval(fileTime) / nanosecondsPerSecond
        return Date(timeIntervalSince1970: secondsSinceWindowsEpoch - windowsEpoch)
    }
    
    static func parsePlumSQLite(fileURL: URL) -> [StickyNote] {
        var notes: [StickyNote] = []
        var db: OpaquePointer?

        guard sqlite3_open(fileURL.path, &db) == SQLITE_OK else {
            print("Error opening plum.sqlite database")
            return notes
        }

        // Check if Note table exists and query it
        let sql = "SELECT Text, CreatedAt, UpdatedAt FROM Note;"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let textPtr = sqlite3_column_text(statement, 0) {
                    let text = String(cString: textPtr)

                    var note = StickyNote(text: text, color: .yellow)

                    // Parse CreatedAt if available
                    if sqlite3_column_type(statement, 1) != SQLITE_NULL {
                        let createdAtValue = sqlite3_column_int64(statement, 1)
                        note.createdAt = fileTimeToDate(UInt64(bitPattern: createdAtValue))
                    }

                    // Parse UpdatedAt if available
                    if sqlite3_column_type(statement, 2) != SQLITE_NULL {
                        let updatedAtValue = sqlite3_column_int64(statement, 2)
                        note.modifiedAt = fileTimeToDate(UInt64(bitPattern: updatedAtValue))
                    }

                    notes.append(note)
                }
            }
        } else {
            // Try alternative schema
            parseAlternativeSchema(db: db, notes: &notes)
        }

        sqlite3_finalize(statement)
        sqlite3_close(db)

        return notes
    }
    
    private static func parseAlternativeSchema(db: OpaquePointer?, notes: inout [StickyNote]) {
        // Try different table structures based on Windows Sticky Notes versions
        // Use whitelist to prevent SQL injection
        let tables = ["Note", "Notes", "StickyNotes", "NoteData"]

        for table in tables {
            // Use parameterized query with whitelist validation
            let sql = "SELECT * FROM \(table) LIMIT 1;"
            var statement: OpaquePointer?
            
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                // Get column count and names
                let columnCount = sqlite3_column_count(statement)
                var textColumn = -1
                var dateColumn = -1
                
                for i in 0..<columnCount {
                    let name = String(cString: sqlite3_column_name(statement, i))
                    if name.contains("Text") || name.contains("Content") || name.contains("Body") {
                        textColumn = Int(i)
                    }
                    if name.contains("Date") || name.contains("Time") {
                        dateColumn = Int(i)
                    }
                }
                
                sqlite3_finalize(statement)
                
                // Now fetch all rows
                let fetchSQL = "SELECT * FROM \(table);"
                var fetchStmt: OpaquePointer?
                
                if sqlite3_prepare_v2(db, fetchSQL, -1, &fetchStmt, nil) == SQLITE_OK {
                    while sqlite3_step(fetchStmt) == SQLITE_ROW {
                        if textColumn >= 0, let textPtr = sqlite3_column_text(fetchStmt, Int32(textColumn)) {
                            let text = String(cString: textPtr)
                            let note = StickyNote(text: text, color: .yellow)
                            notes.append(note)
                        }
                    }
                }
                
                sqlite3_finalize(fetchStmt)
                break
            }
            
            sqlite3_finalize(statement)
        }
    }
    
    static func exportNotesToJSON(notes: [StickyNote], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(notes)
        try data.write(to: url)
    }
    
    static func importNotesFromJSON(url: URL) throws -> [StickyNote] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([StickyNote].self, from: data)
    }
}
