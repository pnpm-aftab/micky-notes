import Foundation
import Combine

class SyncManager: ObservableObject {
    @Published var isSyncing = false
    @Published var isConnected = false
    @Published var lastSyncDate: Date?
    
    private let webSocketServer = WebSocketServer.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupWebSocketCallbacks()
    }
    
    private func setupWebSocketCallbacks() {
        webSocketServer.onConnectionChange = { [weak self] connected in
            DispatchQueue.main.async {
                self?.isConnected = connected
            }
        }
        
        webSocketServer.onMessageReceived = { [weak self] note in
            DispatchQueue.main.async {
                self?.handleIncomingNote(note)
            }
        }
    }
    
    func startSync() {
        webSocketServer.start()
        isSyncing = true
    }
    
    func stopSync() {
        webSocketServer.stop()
        isSyncing = false
        isConnected = false
    }
    
    private func handleIncomingNote(_ note: StickyNote) {
        let db = DatabaseManager.shared
        let existingNotes = db.fetchNotes()

        if let index = existingNotes.firstIndex(where: { $0.id == note.id }) {
            // Update existing note if newer
            if note.modifiedAt > existingNotes[index].modifiedAt {
                db.saveNote(note: note)
            }
        } else {
            // Add new note
            db.saveNote(note: note)
        }

        lastSyncDate = Date()
    }
    
    func broadcastNoteChange(_ note: StickyNote, action: String) {
        webSocketServer.broadcastNote(note, action: action)
        lastSyncDate = Date()
    }
}
