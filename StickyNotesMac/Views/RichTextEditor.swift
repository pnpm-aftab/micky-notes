import SwiftUI
import AppKit

// Custom NSTextView with keyboard shortcuts
class FormattableTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        // Handle keyboard shortcuts
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command) else {
            super.keyDown(with: event)
            return
        }

        guard let character = event.charactersIgnoringModifiers?.lowercased().first else {
            super.keyDown(with: event)
            return
        }

        switch character {
        case "b":
            toggleFontTrait(.bold)
            return
        case "i":
            toggleFontTrait(.italic)
            return
        case "u":
            toggleSimpleAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue)
            return
        default:
            break
        }

        super.keyDown(with: event)
    }
}

struct RichTextEditor: NSViewRepresentable {
    @Binding var attributedString: NSAttributedString
    @Binding var textView: NSTextView?
    var onTextChanged: ((NSAttributedString) -> Void)?
    @FocusState var isFocused: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.textBackgroundColor
        
        let contentSize = scrollView.contentSize
        
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        
        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)
        
        let textView = FormattableTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)

        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textColor = NSColor.labelColor
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textContainerInset = NSSize(width: 16, height: 16)
        
        // Critical: Enable proper resizing behavior
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView

        // Store reference in coordinator
        context.coordinator.textView = textView
        
        // Expose textView to parent
        DispatchQueue.main.async {
            self.textView = textView
        }

        // Set initial text
        if attributedString.length > 0 {
            print("DEBUG: Setting initial text, length: \(attributedString.length)")
            textView.textStorage?.setAttributedString(attributedString)
            print("DEBUG: Initial text set, textView now has \(textView.attributedString().length) chars")
            print("DEBUG: TextView textColor: \(String(describing: textView.textColor))")
            print("DEBUG: TextView backgroundColor: \(String(describing: textView.backgroundColor))")
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? NSTextView else { return }

        // Only update if the text has changed from outside (not from typing)
        if context.coordinator.preventUpdates {
            return
        }

        let currentTextViewString = textView.attributedString()

        // Check if the binding actually differs from what's in the text view
        if !currentTextViewString.isEqual(to: attributedString) {
            // Store the current selected range
            let selectedRange = textView.selectedRange()

            // Only update if the length is different or content is meaningfully different
            // This prevents updates when the text is the same but just formatted differently
            if currentTextViewString.length != attributedString.length ||
               currentTextViewString.string != attributedString.string {

                print("DEBUG: Updating NSView with attributedString, length: \(attributedString.length)")

                // Apply the update with undo grouping
                textView.undoManager?.beginUndoGrouping()
                textView.textStorage?.setAttributedString(attributedString)
                textView.undoManager?.endUndoGrouping()

                // Restore selection if it's still valid
                if selectedRange.location <= textView.string.count {
                    textView.setSelectedRange(selectedRange)
                }

                print("DEBUG: After update, textView has \(textView.attributedString().length) chars")
            }
        }

        // Handle focus
        if isFocused && nsView.window?.firstResponder != textView {
            nsView.window?.makeFirstResponder(textView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        weak var textView: NSTextView?
        var preventUpdates = false

        init(_ parent: RichTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }

            // Prevent updateNSView from overwriting the text while we're updating the binding
            preventUpdates = true

            let newAttributedString = textView.attributedString()

            // Update the binding
            parent.attributedString = newAttributedString

            // Notify parent of the change
            parent.onTextChanged?(newAttributedString)

            // Small delay to prevent immediate update cycle
            DispatchQueue.main.async {
                self.preventUpdates = false
            }
        }
    }
}

// Extension to support NSAttributedString comparison
extension NSAttributedString {
    func isEqual(to other: NSAttributedString) -> Bool {
        return self.isEqual(other)
    }
}

extension NSTextView {
    private var defaultFontSize: CGFloat { 15 }

    fileprivate func resolvedFont(for range: NSRange) -> NSFont {
        if range.length > 0, let storage = textStorage, range.location < storage.length,
           let font = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont {
            return font
        }

        if let typingFont = typingAttributes[.font] as? NSFont {
            return typingFont
        }

        return NSFont.systemFont(ofSize: defaultFontSize)
    }

    func applyFont(_ font: NSFont, to range: NSRange) {
        if range.length > 0 {
            guard let storage = textStorage else { return }
            storage.addAttribute(.font, value: font, range: range)
            didChangeText()
        } else {
            typingAttributes[.font] = font
        }
    }

    func toggleFontTrait(_ trait: NSFontDescriptor.SymbolicTraits) {
        let range = selectedRange()
        let baseFont = resolvedFont(for: range)
        let hasTrait = baseFont.fontDescriptor.symbolicTraits.contains(trait)
        var traits = baseFont.fontDescriptor.symbolicTraits
        
        if hasTrait {
            traits.remove(trait)
        } else {
            traits.insert(trait)
        }

        // Try to create a font with the combined traits
        let newFont = createFont(with: traits, size: baseFont.pointSize)
        applyFont(newFont, to: range)
    }
    
    private func createFont(with traits: NSFontDescriptor.SymbolicTraits, size: CGFloat) -> NSFont {
        // Start with system font
        var font = NSFont.systemFont(ofSize: size)
        
        // Apply bold if needed
        if traits.contains(.bold) {
            font = NSFont.boldSystemFont(ofSize: size)
        }
        
        // Apply italic if needed
        if traits.contains(.italic) {
            let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
            if let newFont = NSFont(descriptor: descriptor, size: size) {
                return newFont
            }
            // Fallback: create italic descriptor manually if above fails
            var italicTraits = font.fontDescriptor.symbolicTraits
            italicTraits.insert(.italic)
            let italicDescriptor = font.fontDescriptor.withSymbolicTraits(italicTraits)
            if let italicFont = NSFont(descriptor: italicDescriptor, size: size) {
                return italicFont
            }
        }
        
        // If we got here, try to apply all traits at once
        let descriptor = NSFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits(traits)
        let finalFont = NSFont(descriptor: descriptor, size: size)
        if finalFont != nil {
            return finalFont!
        }
        
        // Final fallback
        return font
    }

    func toggleSimpleAttribute(_ key: NSAttributedString.Key, value: Int) {
        let range = selectedRange()
        if range.length > 0 {
            guard let storage = textStorage else { return }
            let current = (storage.attribute(key, at: range.location, effectiveRange: nil) as? Int) == value
            if current {
                storage.removeAttribute(key, range: range)
            } else {
                storage.addAttribute(key, value: value, range: range)
            }
            didChangeText()
        } else {
            let current = (typingAttributes[key] as? Int) == value
            if current {
                typingAttributes.removeValue(forKey: key)
            } else {
                typingAttributes[key] = value
            }
        }
    }
}
