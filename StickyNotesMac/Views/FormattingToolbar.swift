import SwiftUI
import AppKit

struct FormattingToolbar: View {
    @Binding var textView: NSTextView?
    @State private var isBold = false
    @State private var isItalic = false
    @State private var isUnderlined = false
    @State private var isStrikethrough = false
    @State private var selectionChangeTimer: Timer?

    var body: some View {
        HStack(spacing: 8) {
            // Basic Formatting Group
            formattingButton("bold", icon: "bold", isActive: isBold) {
                toggleBold()
            }
            formattingButton("italic", icon: "italic", isActive: isItalic) {
                toggleItalic()
            }
            formattingButton("underline", icon: "underline", isActive: isUnderlined) {
                toggleUnderline()
            }
            formattingButton("strikethrough", icon: "strikethrough", isActive: isStrikethrough) {
                toggleStrikethrough()
            }

            Divider()
                .frame(height: 20)

            // Heading Styles
            Menu {
                Button("Heading 1") { applyHeading(.heading1) }
                Button("Heading 2") { applyHeading(.heading2) }
                Button("Heading 3") { applyHeading(.heading3) }
                Button("Body") { applyHeading(.body) }
            } label: {
                Image(systemName: "textformat.size")
                    .font(.system(size: 13))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28, height: 28)
            .help("Heading style")

            Divider()
                .frame(height: 20)

            // Lists
            formattingButton("list.bullet", icon: "list.bullet") {
                toggleList(.bulleted)
            }
            formattingButton("list.number", icon: "list.number") {
                toggleList(.numbered)
            }

            Divider()
                .frame(height: 20)

            // Code Block
            formattingButton("curlybraces", icon: "curlybraces") {
                toggleCodeBlock()
            }

            Divider()
                .frame(height: 20)

            // Highlight Color
            Menu {
                Button("None") { applyHighlight(nil) }
                Button("Yellow") { applyHighlight(NSColor.yellow) }
                Button("Green") { applyHighlight(NSColor.green) }
                Button("Blue") { applyHighlight(NSColor.blue) }
                Button("Purple") { applyHighlight(NSColor.purple) }
                Button("Orange") { applyHighlight(NSColor.orange) }
            } label: {
                Image(systemName: "highlighter")
                    .font(.system(size: 13))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28, height: 28)
            .help("Highlight color")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            startMonitoringSelection()
        }
        .onDisappear {
            selectionChangeTimer?.invalidate()
        }
    }

    private func formattingButton(_ name: String, icon: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
                .foregroundColor(isActive ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .help(name.capitalized)
    }

    // MARK: - Formatting Actions

    private func toggleBold() {
        guard let textView = textView else { return }
        textView.toggleFontTrait(.bold)
        notifyTextChanged()
        updateActiveStates()
    }

    private func toggleItalic() {
        guard let textView = textView else { return }
        textView.toggleFontTrait(.italic)
        notifyTextChanged()
        updateActiveStates()
    }

    private func toggleUnderline() {
        guard let textView = textView else { return }
        textView.toggleSimpleAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue)
        notifyTextChanged()
        updateActiveStates()
    }

    private func toggleStrikethrough() {
        guard let textView = textView else { return }
        textView.toggleSimpleAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue)
        notifyTextChanged()
        updateActiveStates()
    }

    enum HeadingStyle {
        case heading1, heading2, heading3, body
    }

    private func applyHeading(_ style: HeadingStyle) {
        guard let textView = textView else { return }

        let range = textView.selectedRange()
        let fontSize: CGFloat
        let isBold: Bool

        switch style {
        case .heading1:
            fontSize = 24
            isBold = true
        case .heading2:
            fontSize = 20
            isBold = true
        case .heading3:
            fontSize = 16
            isBold = true
        case .body:
            fontSize = 15
            isBold = false
        }

        let font = isBold ? NSFont.boldSystemFont(ofSize: fontSize) : NSFont.systemFont(ofSize: fontSize)
        textView.applyFont(font, to: range)
        notifyTextChanged()
        updateActiveStates()
    }

    enum ListStyle {
        case bulleted, numbered
    }

    private func toggleList(_ style: ListStyle) {
        guard let textView = textView else { return }

        let range = textView.selectedRange()
        guard let paragraphRange = textView.textStorage?.mutableString.paragraphRange(for: range) else { return }

        // Get current paragraph text
        let currentText = textView.textStorage?.attributedSubstring(from: paragraphRange).string ?? ""
        let markerPrefix = style == .bulleted ? "• " : "1. "
        let isList = currentText.hasPrefix(markerPrefix)

        if isList {
            // Remove list marker
            let newText = String(currentText.dropFirst(markerPrefix.count))
            textView.replaceCharacters(in: paragraphRange, with: newText)
        } else {
            // Add list marker at the beginning of paragraph
            textView.replaceCharacters(in: NSRange(location: paragraphRange.location, length: 0), with: markerPrefix)
        }
        notifyTextChanged()
    }

    private func toggleCodeBlock() {
        guard let textView = textView else { return }

        let range = textView.selectedRange()
        guard range.length > 0 else { return }
        
        let font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)

        textView.textStorage?.addAttribute(.font, value: font, range: range)
        textView.textStorage?.addAttribute(.backgroundColor, value: NSColor.controlBackgroundColor, range: range)
        notifyTextChanged()
    }

    private func applyHighlight(_ color: NSColor?) {
        guard let textView = textView else { return }

        let range = textView.selectedRange()
        if range.length == 0 { return }

        if let color = color {
            textView.textStorage?.addAttribute(.backgroundColor, value: color, range: range)
        } else {
            textView.textStorage?.removeAttribute(.backgroundColor, range: range)
        }
        notifyTextChanged()
    }

    
    private func notifyTextChanged() {
        guard let textView = textView else { return }
        // Trigger delegate notification so the binding updates
        NotificationCenter.default.post(
            name: NSText.didChangeNotification,
            object: textView
        )
    }
    
    private func startMonitoringSelection() {
        selectionChangeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateActiveStates()
        }
    }
    
    private func updateActiveStates() {
        guard let textView = textView else {
            isBold = false
            isItalic = false
            isUnderlined = false
            isStrikethrough = false
            return
        }
        
        let range = textView.selectedRange()
        var attributes: [NSAttributedString.Key: Any]? = nil
        
        // For a selection with length, check at the start position
        if range.length > 0, let storage = textView.textStorage, range.location < storage.length {
            attributes = storage.attributes(at: range.location, effectiveRange: nil)
        } else {
            // For cursor position (no selection), prioritize typing attributes
            attributes = textView.typingAttributes
        }
        
        // Check bold/italic from font
        if let font = attributes?[.font] as? NSFont {
            let traits = font.fontDescriptor.symbolicTraits
            isBold = traits.contains(.bold)
            isItalic = traits.contains(.italic)
        } else {
            isBold = false
            isItalic = false
        }
        
        // Check underline
        isUnderlined = (attributes?[.underlineStyle] as? Int) == NSUnderlineStyle.single.rawValue
        
        // Check strikethrough
        isStrikethrough = (attributes?[.strikethroughStyle] as? Int) == NSUnderlineStyle.single.rawValue
    }
}
