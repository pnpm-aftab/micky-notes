import SwiftUI

struct NoteEditorView: View {
    @Binding var note: StickyNote
    let viewModel: NotesViewModel
    @FocusState private var isFocused: Bool
    @State private var showSaveIndicator = false

    var body: some View {
        VStack(spacing: 0) {
            toolbarView
            Divider()
            editorView
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .navigationTitle(note.text.isEmpty ? "New Note" : String(note.text.prefix(30)))
    }

    private var toolbarView: some View {
        HStack(spacing: 12) {
            colorPicker
            Spacer()
            saveIndicator
            deleteButton
        }
        .padding(12)
        .background(note.color.displayColor)
    }

    private var colorPicker: some View {
        HStack(spacing: 4) {
            ForEach(NoteColor.allCases, id: \.self) { color in
                colorButton(for: color)
            }
        }
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
            textEditor
        }
    }

    private var placeholder: some View {
        Group {
            if note.text.isEmpty {
                Text("Start typing...")
                    .font(.system(size: 15))
                    .foregroundColor(Color.secondary.opacity(0.6))
                    .padding(16)
                    .allowsHitTesting(false)
            }
        }
    }

    private var textEditor: some View {
        TextEditor(text: $note.text)
            .font(.system(size: 15))
            .foregroundColor(Color.primary)
            .focused($isFocused)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .padding(16)
            .onChange(of: note.text) { oldValue, newValue in
                note.modifiedAt = Date()
                viewModel.updateNote(note)
                triggerSaveFeedback()
            }
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
