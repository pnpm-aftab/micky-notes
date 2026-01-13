import Foundation
import Network

class WebSocketServer: NSObject {
    static let shared = WebSocketServer()
    private var listener: NWListener?
    private var connections: [NWConnection] = []

    var onMessageReceived: ((StickyNote) -> Void)?
    var onConnectionChange: ((Bool) -> Void)?
    var onError: ((String) -> Void)?

    private override init() {
        super.init()
    }

    func start() {
        let config = NWParameters(tls: nil)
        config.allowLocalEndpointReuse = true
        config.allowFastOpen = true

        do {
            listener = try NWListener(using: config, on: .http)
            listener?.service = NWListener.Service(name: "StickyNotes", type: "_stickynotes._tcp", domain: nil)

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: .main)
            print("WebSocket server started on local network")
        } catch {
            let errorMsg = "Error starting server: \(error.localizedDescription)"
            print(errorMsg)
            onError?(errorMsg)
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        onConnectionChange?(true)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Client connected")
                self?.receiveMessage(from: connection)
            case .failed(let error):
                let errorMsg = "Connection failed: \(error.localizedDescription)"
                print(errorMsg)
                self?.removeConnection(connection)
                self?.onConnectionChange?(false)
                self?.onError?(errorMsg)
            case .waiting(let error):
                print("Connection waiting: \(error)")
            default:
                break
            }
        }

        connection.start(queue: .main)
    }

    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll { $0 === connection }
    }
    
    private func receiveMessage(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, context, isComplete, error) in
            if let data = data, !data.isEmpty {
                self?.processMessage(data)
            }
            
            if !isComplete && error == nil {
                self?.receiveMessage(from: connection)
            }
        }
    }
    
    private func processMessage(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let type = json["type"] as? String,
               type == "note_update",
               let noteData = json["note"] as? [String: Any] {
                
                let noteData = try JSONSerialization.data(withJSONObject: noteData)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let note = try decoder.decode(StickyNote.self, from: noteData)
                
                DispatchQueue.main.async {
                    self.onMessageReceived?(note)
                }
            }
        } catch {
            print("Error processing message: \(error)")
        }
    }
    
    func broadcastNote(_ note: StickyNote, action: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let noteData = try encoder.encode(note)
            let noteJSON = try JSONSerialization.jsonObject(with: noteData)
            
            let message: [String: Any] = [
                "type": "note_update",
                "action": action,
                "note": noteJSON
            ]
            
            let messageData = try JSONSerialization.data(withJSONObject: message)
            
            for connection in connections {
                connection.send(content: messageData, completion: .contentProcessed { error in
                    if let error = error {
                        print("Error sending message: \(error)")
                    }
                })
            }
        } catch {
            print("Error encoding message: \(error)")
        }
    }
    
    func stop() {
        listener?.cancel()
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
    }
}
