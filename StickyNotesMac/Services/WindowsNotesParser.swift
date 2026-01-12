import Foundation
import SQLite3

class WindowsNotesParser {
    
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
                    
                    // Windows stores dates as FileTime (100-nanosecond intervals since Jan 1, 1601)
                    // We'll use current date for now
                    let note = StickyNote(text: text, color: .yellow)
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
        let tables = ["Note", "Notes", "StickyNotes"]
        
        for table in tables {
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
