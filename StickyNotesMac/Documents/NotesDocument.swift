import SwiftUI
import UniformTypeIdentifiers

struct NotesDocument: FileDocument {
    var notes: [StickyNote]
    
    static var readableContentTypes: [UTType] {
        [.json]
    }
    
    static var writableContentTypes: [UTType] {
        [.json]
    }
    
    init(notes: [StickyNote]) {
        self.notes = notes
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.notes = try decoder.decode([StickyNote].self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(notes)
        return FileWrapper(regularFileWithContents: data)
    }
}
