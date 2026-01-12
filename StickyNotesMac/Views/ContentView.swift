import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = NotesViewModel()
    @State private var searchText = ""
    @State private var showingImporter = false
    @State private var showingExporter = false

    var filteredNotes: [StickyNote] {
        if searchText.isEmpty {
            return viewModel.notes
        }
        return viewModel.notes.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
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
                                viewModel.deleteNote(note)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .opacity(0.6)
                            .help("Delete note")
                        }
                    }
                }
                .listStyle(.sidebar)
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
                    Text("Select a note or create a new one")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)

                    Button(action: {
                        let newNote = viewModel.createNote()
                        viewModel.selectNote(newNote)
                    }) {
                        Text("New Note")
                            .font(.system(size: 13))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Import from Windows") {
                        showingImporter = true
                    }
                    Button("Export Notes") {
                        showingExporter = true
                    }
                    Divider()
                    Button(viewModel.isSyncing ? "Stop Sync" : "Start Sync") {
                        viewModel.toggleSync()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    let newNote = viewModel.createNote()
                    viewModel.selectNote(newNote)
                } label: {
                    Image(systemName: "plus")
                }
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
                print("Import error: \(error)")
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: NotesDocument(notes: viewModel.notes),
            contentType: .json,
            defaultFilename: "sticky_notes_export"
        ) { result in
            if case .failure(let error) = result {
                print("Export error: \(error)")
            }
        }
    }
}

struct NoteRowView: View {
    let note: StickyNote

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(note.color.displayColor)
                .frame(width: 8, height: 8)

            Text(note.text.isEmpty ? "New Note" : note.text)
                .font(.system(size: 13))
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}
