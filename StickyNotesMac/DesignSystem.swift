import SwiftUI

// MARK: - Design System
// Minimal spacing and modular scale for consistent UI

extension Color {
    // Core colors
    static let background = Color(red: 1.0, green: 1.0, blue: 1.0)      // #FFFFFF
    static let surface = Color(red: 0.97, green: 0.97, blue: 0.97)      // #F8F8F8
    static let border = Color(red: 0.91, green: 0.91, blue: 0.92)       // #E8E8E8
    static let accent = Color(red: 0.2, green: 0.5, blue: 1.0)          // #3380FF

    // Text colors
    static let textPrimary = Color.black
    static let textSecondary = Color(red: 0.56, green: 0.56, blue: 0.58) // #8E8E93
}

// MARK: - Spacing Scale
enum Design {
    enum Spacing {
        static let hairline: CGFloat = 2
        static let tight: CGFloat = 4
        static let compact: CGFloat = 6
        static let standard: CGFloat = 8
        static let section: CGFloat = 12
        static let container: CGFloat = 16
    }

    enum BorderRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 6
        static let large: CGFloat = 8
    }

    enum Font {
        static let caption: CGFloat = 11
        static let body: CGFloat = 13
        static let primary: CGFloat = 15
        static let header: CGFloat = 17
        static let title: CGFloat = 22
    }

    enum Animation {
        static let pressScale: CGFloat = 0.97
        static let duration: Double = 0.14
    }
}

// MARK: - Standard Button Style
struct StandardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Design.Animation.pressScale : 1.0)
            .animation(.easeOut(duration: Design.Animation.duration), value: configuration.isPressed)
    }
}
