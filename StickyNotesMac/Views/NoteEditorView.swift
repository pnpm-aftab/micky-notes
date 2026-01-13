import SwiftUI
import AppKit

struct NoteEditorView: View {
    @Binding var note: StickyNote
    let viewModel: NotesViewModel
    @FocusState private var isFocused: Bool
    @State private var showSaveIndicator = false
    @State private var attributedString: NSAttributedString
    @State private var textViewRef: NSTextView?

    init(note: Binding<StickyNote>, viewModel: NotesViewModel) {
        self._note = note
        self.viewModel = viewModel
        self._attributedString = State(initialValue: note.wrappedValue.decodeAttributedString())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Formatting toolbar
            FormattingToolbar(textView: $textViewRef)

            Divider()

            // Color picker toolbar
            colorPickerToolbar

            Divider()

            // Rich text editor
            editorView
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .navigationTitle(title)
        .onAppear {
            loadContent()
        }
    }

    private var title: String {
        let plainText = attributedString.string
        let preview = plainText.isEmpty ? "New Note" : String(plainText.prefix(30))
        return preview
    }

    private var colorPickerToolbar: some View {
        HStack(spacing: 12) {
            // Color picker
            HStack(spacing: 4) {
                ForEach(NoteColor.allCases, id: \.self) { color in
                    colorButton(for: color)
                }
            }

            Spacer()

            // Actions
            saveIndicator
            deleteButton
        }
        .padding(12)
        .background(note.color.displayColor)
    }

    private func colorButton(for color: NoteColor) -> some View {
        Button {
            note.color = color
            note.modifiedAt = Date()
            viewModel.updateNote(note)
            triggerSaveFeedback()
        } label: {
            Circle()
                .fill(color.displayColor)
                .frame(width: 16, height: 16)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .opacity(note.color == color ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
    }

    private var saveIndicator: some View {
        Group {
            if showSaveIndicator {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("Saved")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .transition(.opacity)
            }
        }
    }

    private var deleteButton: some View {
        Button {
            let noteToDelete = note
            viewModel.deleteNote(noteToDelete)
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 14))
                .foregroundColor(.primary)
        }
        .buttonStyle(.plain)
    }

    private var editorView: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .textBackgroundColor)
            placeholder
            richTextEditor
        }
    }

    private var placeholder: some View {
        Group {
            if attributedString.string.isEmpty {
                Text("Start typing...")
                    .font(.system(size: 15))
                    .foregroundColor(Color.secondary.opacity(0.6))
                    .padding(16)
                    .allowsHitTesting(false)
            }
        }
    }

    private var richTextEditor: some View {
        RichTextEditor(
            attributedString: $attributedString,
            textView: $textViewRef,
            onTextChanged: { newAttributedString in
                note.attributedText = StickyNote.encodeAttributedString(newAttributedString)
                note.modifiedAt = Date()
                viewModel.updateNote(note)
                triggerSaveFeedback()
            }
        )
        .focused($isFocused)
        .onAppear {
            isFocused = true
        }
    }

    private func loadContent() {
        attributedString = note.decodeAttributedString()
    }

    private func triggerSaveFeedback() {
        withAnimation {
            showSaveIndicator = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showSaveIndicator = false
            }
        }
    }
}
