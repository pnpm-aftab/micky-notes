import SwiftUI
import Foundation

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
    var text: String
    var createdAt: Date
    var modifiedAt: Date
    var color: NoteColor

    init(id: UUID = UUID(), text: String, color: NoteColor = .yellow) {
        self.id = id
        self.text = text
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.color = color
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
