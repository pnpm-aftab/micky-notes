import Foundation
import Combine

class NotesViewModel: ObservableObject {
    @Published var notes: [StickyNote] = []
    @Published var selectedNote: StickyNote?
    @Published var isSyncing = false
    @Published var isConnected = false

    private let database = DatabaseManager.shared
    private let syncManager = SyncManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadNotes()
        setupSyncCallbacks()
    }

    private func setupSyncCallbacks() {
        syncManager.$isSyncing
            .assign(to: &$isSyncing)

        syncManager.$isConnected
            .assign(to: &$isConnected)

        syncManager.$isConnected
            .sink { [weak self] connected in
                if connected {
                    self?.loadNotes()
                }
            }
            .store(in: &cancellables)
    }

    func loadNotes() {
        notes = database.fetchNotes()
        print("Loaded \(notes.count) notes from database")
    }

    func createNote() -> StickyNote {
        let newNote = StickyNote(text: "")
        notes.insert(newNote, at: 0)
        database.saveNote(note: newNote)
        selectedNote = newNote
        syncManager.broadcastNoteChange(newNote, action: "create")
        print("Created new note with id: \(newNote.id)")
        return newNote
    }

    func updateNote(_ note: StickyNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index] = note
            database.saveNote(note: note)
            syncManager.broadcastNoteChange(note, action: "update")
            print("Updated note: \(note.id)")
        }
    }

    func deleteNote(_ note: StickyNote) {
        notes.removeAll { $0.id == note.id }
        database.deleteNote(id: note.id)
        if selectedNote?.id == note.id {
            selectedNote = nil
        }
        syncManager.broadcastNoteChange(note, action: "delete")
        print("Deleted note: \(note.id)")
    }

    func selectNote(_ note: StickyNote?) {
        selectedNote = note
    }

    func importFromWindows(fileURL: URL) {
        let importedNotes = WindowsNotesParser.parsePlumSQLite(fileURL: fileURL)

        for note in importedNotes {
            // Check if note already exists
            if !notes.contains(where: { $0.id == note.id }) {
                notes.insert(note, at: 0)
                database.saveNote(note: note)
            }
        }

        syncManager.broadcastNoteChange(importedNotes.first!, action: "import")
    }

    func toggleSync() {
        if isSyncing {
            syncManager.stopSync()
        } else {
            syncManager.startSync()
        }
    }
}
