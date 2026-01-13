import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = NotesViewModel()
    @State private var searchText = ""
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var noteToDelete: StickyNote?
    @State private var showingDeleteAlert = false
    @FocusState private var searchFieldFocused: Bool

    var filteredNotes: [StickyNote] {
        if searchText.isEmpty {
            return viewModel.notes
        }
        return viewModel.notes.filter { note in
            let plainText = note.decodeAttributedString().string
            return plainText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    TextField("Search", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($searchFieldFocused)
                        .accessibilityLabel("Search notes")
                        .accessibilityHint("Type to filter your notes")
                }
                .padding(12)

                // Notes list
                List(selection: $viewModel.selectedNote) {
                    ForEach(filteredNotes) { note in
                        HStack(spacing: 8) {
                            NoteRowView(note: note)
                                .tag(note)
                                .onTapGesture {
                                    viewModel.selectNote(note)
                                }
                            Spacer()
                            Button {
                                noteToDelete = note
                                showingDeleteAlert = true
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .opacity(0.6)
                            .accessibilityLabel("Delete note")
                            .accessibilityHint("Delete this note")
                        }
                    }
                }
                .listStyle(.sidebar)

                // Sidebar toolbar
                sidebarToolbar

                // Sync status indicator
                if viewModel.isSyncing {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isConnected ? "Connected" : "Disconnected")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            // Detail view
            if let note = viewModel.selectedNote,
               viewModel.notes.contains(where: { $0.id == note.id }) {
                NoteEditorView(note: Binding(
                    get: {
                        // Double-check the note still exists
                        if let currentIndex = viewModel.notes.firstIndex(where: { $0.id == note.id }) {
                            return viewModel.notes[currentIndex]
                        }
                        return note
                    },
                    set: { newNote in
                        viewModel.updateNote(newNote)
                    }
                ), viewModel: viewModel)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "note.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No Note Selected")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                    Text("Create a new note or select one from the sidebar")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        if let newNote = viewModel.createNote() {
                            viewModel.selectNote(newNote)
                        }
                    }) {
                        Text("New Note (⌘N)")
                            .font(.system(size: 13))
                    }
                    .keyboardShortcut("n", modifiers: [.command])
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.database],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.importFromWindows(fileURL: url)
                }
            case .failure(let error):
                viewModel.errorMessage = "Import failed: \(error.localizedDescription)"
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: NotesDocument(notes: viewModel.notes),
            contentType: .json,
            defaultFilename: "sticky_notes_export"
        ) { result in
            if case .failure(let error) = result {
                viewModel.errorMessage = "Export failed: \(error.localizedDescription)"
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil), presenting: viewModel.errorMessage) { _ in
            Button("OK") {
                viewModel.clearError()
            }
        } message: { error in
            Text(error)
        }
        .alert("Delete Note?", isPresented: $showingDeleteAlert, presenting: noteToDelete) { note in
            Button("Cancel", role: .cancel) {
                noteToDelete = nil
            }
            Button("Delete", role: .destructive) {
                viewModel.deleteNote(note)
                noteToDelete = nil
            }
        } message: { note in
            let preview = note.decodeAttributedString().string.isEmpty ? "New Note" : String(note.decodeAttributedString().string.prefix(30))
            Text("Are you sure you want to delete \"\(preview)\"? This action cannot be undone.")
        }
        .alert("Sync Error", isPresented: .constant(viewModel.syncErrorMessage != nil), presenting: viewModel.syncErrorMessage) { _ in
            Button("OK") {
                viewModel.clearError()
            }
        } message: { error in
            Text(error)
        }
        .onAppear {
            // Add keyboard shortcut for search
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 6 && (event.modifierFlags.contains(.command)) {
                    // Cmd+F
                    searchFieldFocused = true
                    return nil
                }
                return event
            }
        }
    }

    // MARK: - Sidebar Toolbar

    private var sidebarToolbar: some View {
        HStack(spacing: 8) {
            // New note button
            Button {
                if let newNote = viewModel.createNote() {
                    viewModel.selectNote(newNote)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help("New note")

            Spacer()

            // Sync toggle button
            Button {
                viewModel.toggleSync()
            } label: {
                Image(systemName: viewModel.isSyncing ? "stop.circle" : "play.circle")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help(viewModel.isSyncing ? "Stop sync" : "Start sync")

            // Import button
            Button {
                showingImporter = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help("Import from Windows")

            // Export button
            Button {
                showingExporter = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .help("Export notes")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct NoteRowView: View {
    let note: StickyNote

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(note.color.displayColor)
                .frame(width: 8, height: 8)

            Text(displayText)
                .font(.system(size: 13))
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }

    private var displayText: String {
        let plainText = note.decodeAttributedString().string
        return plainText.isEmpty ? "New Note" : plainText
    }
}
