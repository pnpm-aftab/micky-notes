import Foundation
import Network
import SystemConfiguration

class WebSocketServer: NSObject {
    static let shared = WebSocketServer()
    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var serverPort: NWEndpoint.Port?

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

        // Use TCP instead of HTTP for raw WebSocket-like connections
        do {
            // Use fixed port 8080
            listener = try NWListener(using: .tcp, on: 8080)
            listener?.service = NWListener.Service(name: "StickyNotes", type: "_stickynotes._tcp", domain: nil)

            listener?.newConnectionHandler = { [weak self] connection in
                print("New connection attempt from \(connection.endpoint)")
                self?.handleConnection(connection)
            }

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    if let port = self?.serverPort {
                        let localIP = self?.getLocalIPAddress() ?? "unknown"
                        print("✅ WebSocket server listening on \(localIP):\(port)")
                        print("   Use this IP on Windows: python windows_companion.py \(localIP)")
                    }
                case .failed(let error):
                    print("❌ Server failed: \(error)")
                default:
                    break
                }
            }

            // Store the port before starting
            if let port = listener?.port {
                self.serverPort = port
            }

            listener?.start(queue: .main)
            print("Starting WebSocket server...")
        } catch {
            let errorMsg = "Error starting server: \(error.localizedDescription)"
            print(errorMsg)
            onError?(errorMsg)
        }
    }

    private func getLocalIPAddress() -> String {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return "unknown" }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "en1" {  // WiFi or Ethernet
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }

        return address ?? "10.17.19.29"  // Fallback to known IP
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("✅ Client connected from \(connection.endpoint)")
                self?.connections.append(connection)
                self?.onConnectionChange?(true)
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
        // First read the 4-byte length prefix
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] (lengthData, context, isComplete, error) in
            guard let lengthData = lengthData, lengthData.count == 4 else {
                if !isComplete && error == nil {
                    self?.receiveMessage(from: connection)
                }
                return
            }

            // Parse message length
            let messageLength = lengthData.withUnsafeBytes { bytes in
                UInt32(bigEndian: bytes.load(as: UInt32.self))
            }

            // Now read the actual message
            connection.receive(minimumIncompleteLength: Int(messageLength), maximumLength: Int(messageLength)) { [weak self] (data, context, isComplete, error) in
                if let data = data, !data.isEmpty {
                    self?.processMessage(data)
                }

                if !isComplete && error == nil {
                    self?.receiveMessage(from: connection)
                }
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
