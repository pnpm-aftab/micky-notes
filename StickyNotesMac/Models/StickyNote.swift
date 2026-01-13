import SwiftUI
import Foundation
import AppKit

enum NoteColor: String, CaseIterable, Codable {
    case yellow = "Yellow"
    case blue = "Blue"
    case green = "Green"
    case pink = "Pink"
    case purple = "Purple"
    case orange = "Orange"
    case red = "Red"
    case teal = "Teal"
    case indigo = "Indigo"
    case gray = "Gray"

    var colorValue: String {
        switch self {
        case .yellow: return "#F5C842"    // Warmer yellow
        case .blue: return "#4A90D9"      // Darker blue
        case .green: return "#5CB85C"     // Darker green
        case .pink: return "#D9537F"      // Darker pink
        case .purple: return "#8E44AD"    // Darker purple
        case .orange: return "#E67E22"    // Orange
        case .red: return "#C0392B"       // Red
        case .teal: return "#17A2B8"      // Teal
        case .indigo: return "#34495E"    // Dark blue-gray
        case .gray: return "#7F8C8D"      // Gray
        }
    }

    var displayColor: Color {
        Color(hex: self.colorValue)
    }
}

struct StickyNote: Identifiable, Codable, Hashable {
    var id: UUID
    var attributedText: Data
    var createdAt: Date
    var modifiedAt: Date
    var color: NoteColor

    // Computed property for backward compatibility during migration
    var text: String {
        get {
            guard let attrString = try? NSAttributedString(data: attributedText, options: [
                .documentType: NSAttributedString.DocumentType.rtf,
                .characterEncoding: String.Encoding.utf8.rawValue
            ], documentAttributes: nil) else {
                return ""
            }
            return attrString.string
        }
    }

    init(id: UUID = UUID(), text: String, color: NoteColor = .yellow) {
        self.id = id
        // Convert plain text to attributed string with default attributes
        let attrString = NSAttributedString(string: text)
        self.attributedText = Self.encodeAttributedString(attrString)
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.color = color
    }

    init(id: UUID = UUID(), attributedText: Data, color: NoteColor = .yellow) {
        self.id = id
        self.attributedText = attributedText
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.color = color
    }

    // Encoding/Decoding helpers
    static func encodeAttributedString(_ attrString: NSAttributedString) -> Data {
        let range = NSRange(location: 0, length: attrString.length)
        do {
            let data = try attrString.data(from: range, documentAttributes: [
                .documentType: NSAttributedString.DocumentType.rtf,
                .characterEncoding: String.Encoding.utf8.rawValue
            ])
            print("DEBUG: Encoded \(attrString.length) chars to \(data.count) bytes of RTF")
            if data.count > 0 {
                print("DEBUG: RTF preview: \(String(data: data.prefix(100), encoding: .utf8) ?? "invalid")")
            }
            return data
        } catch {
            print("Error encoding attributed string: \(error)")
            return Data()
        }
    }

    func decodeAttributedString() -> NSAttributedString {
        guard !attributedText.isEmpty else {
            print("DEBUG: Decoding empty attributedText")
            return NSAttributedString(string: "")
        }

        print("DEBUG: Decoding \(attributedText.count) bytes of RTF")

        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.rtf,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]

        do {
            let attrString = try NSAttributedString(data: attributedText, options: options, documentAttributes: nil)
            print("DEBUG: Decoded to \(attrString.length) chars: '\(attrString.string.prefix(50))'")
            return attrString
        } catch {
            print("Error decoding attributed string: \(error)")
            return NSAttributedString(string: text)
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
