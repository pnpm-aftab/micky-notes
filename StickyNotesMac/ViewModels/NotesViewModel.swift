import Foundation
import Combine

class NotesViewModel: ObservableObject {
    @Published var notes: [StickyNote] = []
    @Published var selectedNote: StickyNote?
    @Published var isSyncing = false
    @Published var isConnected = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var syncErrorMessage: String?

    private let database = DatabaseManager.shared
    private let syncManager = SyncManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        loadNotes()
        setupSyncCallbacks()
        setupNotificationObserver()
    }

    private func setupSyncCallbacks() {
        syncManager.$isSyncing
            .assign(to: &$isSyncing)

        syncManager.$isConnected
            .assign(to: &$isConnected)

        syncManager.$syncError
            .compactMap { $0 }
            .assign(to: &$syncErrorMessage)

        syncManager.$isConnected
            .sink { [weak self] connected in
                if connected {
                    self?.loadNotes()
                }
            }
            .store(in: &cancellables)
    }

    private func setupNotificationObserver() {
        NotificationCenter.default.publisher(for: .notesDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadNotes()
            }
            .store(in: &cancellables)
    }

    func loadNotes() {
        isLoading = true
        defer { isLoading = false }

        do {
            notes = try database.fetchNotes()
            errorMessage = nil
            print("Loaded \(notes.count) notes from database")
        } catch {
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
            print("Error loading notes: \(error)")
        }
    }

    func createNote() -> StickyNote? {
        // Create empty attributed string and convert to data for rich text support
        let emptyAttributedString = NSAttributedString(string: "")
        let data = StickyNote.encodeAttributedString(emptyAttributedString)
        let newNote = StickyNote(id: UUID(), attributedText: data, color: .yellow)

        do {
            try database.saveNote(note: newNote)
            notes.insert(newNote, at: 0)
            selectedNote = newNote
            syncManager.broadcastNoteChange(newNote, action: "create")
            errorMessage = nil
            print("Created new rich text note with id: \(newNote.id)")
            return newNote
        } catch {
            errorMessage = "Failed to create note: \(error.localizedDescription)"
            print("Error creating note: \(error)")
            return nil
        }
    }

    func updateNote(_ note: StickyNote) {
        do {
            try database.saveNote(note: note)
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = note
            }
            syncManager.broadcastNoteChange(note, action: "update")
            errorMessage = nil
            print("Updated note: \(note.id)")
        } catch {
            errorMessage = "Failed to update note: \(error.localizedDescription)"
            print("Error updating note: \(error)")
        }
    }

    func deleteNote(_ note: StickyNote) {
        do {
            try database.deleteNote(id: note.id)
            notes.removeAll { $0.id == note.id }
            if selectedNote?.id == note.id {
                selectedNote = nil
            }
            syncManager.broadcastNoteChange(note, action: "delete")
            errorMessage = nil
            print("Deleted note: \(note.id)")
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
            print("Error deleting note: \(error)")
        }
    }

    func selectNote(_ note: StickyNote?) {
        selectedNote = note
    }

    func importFromWindows(fileURL: URL) {
        isLoading = true
        defer { isLoading = false }

        let importedNotes = WindowsNotesParser.parsePlumSQLite(fileURL: fileURL)

        guard let firstNote = importedNotes.first else {
            errorMessage = "No notes found in the selected file"
            return
        }

        do {
            for note in importedNotes {
                // Check if note already exists
                if !notes.contains(where: { $0.id == note.id }) {
                    try database.saveNote(note: note)
                    notes.insert(note, at: 0)
                }
            }

            syncManager.broadcastNoteChange(firstNote, action: "import")
            errorMessage = nil
        } catch {
            errorMessage = "Failed to import notes: \(error.localizedDescription)"
        }
    }

    func toggleSync() {
        syncErrorMessage = nil
        if isSyncing {
            syncManager.stopSync()
        } else {
            syncManager.startSync()
        }
    }

    func clearError() {
        errorMessage = nil
        syncErrorMessage = nil
    }
}
