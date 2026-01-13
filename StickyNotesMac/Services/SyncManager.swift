import Foundation
import Combine

class SyncManager: ObservableObject {
    @Published var isSyncing = false
    @Published var isConnected = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?

    private let webSocketServer = WebSocketServer.shared
    private var cancellables = Set<AnyCancellable>()
    private let syncQueue = DispatchQueue(label: "com.stickynotes.sync", qos: .userInitiated)
    private let database = DatabaseManager.shared

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
            self?.handleIncomingNote(note)
        }

        webSocketServer.onError = { [weak self] error in
            DispatchQueue.main.async {
                self?.syncError = error
            }
        }
    }

    func startSync() {
        webSocketServer.start()
        isSyncing = true
        syncError = nil
    }

    func stopSync() {
        webSocketServer.stop()
        isSyncing = false
        isConnected = false
    }

    private func handleIncomingNote(_ note: StickyNote) {
        syncQueue.sync { [weak self] in
            guard let self = self else { return }

            do {
                let existingNotes = try self.database.fetchNotes()

                if let index = existingNotes.firstIndex(where: { $0.id == note.id }) {
                    // Update existing note only if incoming note is newer
                    if note.modifiedAt > existingNotes[index].modifiedAt {
                        try self.database.saveNote(note: note)
                    }
                } else {
                    // Add new note
                    try self.database.saveNote(note: note)
                }

                DispatchQueue.main.async {
                    self.lastSyncDate = Date()
                    NotificationCenter.default.post(name: .notesDidChange, object: nil)
                }
            } catch {
                DispatchQueue.main.async {
                    self.syncError = "Failed to sync note: \(error.localizedDescription)"
                }
            }
        }
    }

    func broadcastNoteChange(_ note: StickyNote, action: String) {
        webSocketServer.broadcastNote(note, action: action)
        lastSyncDate = Date()
    }
}

extension Notification.Name {
    static let notesDidChange = Notification.Name("notesDidChange")
}
