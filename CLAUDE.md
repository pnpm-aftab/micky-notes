# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A native macOS Sticky Notes application that syncs with Windows Sticky Notes over local WiFi. The app uses SwiftUI and stores notes in SQLite with rich text (RTF) support. Cross-platform sync is achieved via WebSocket server/client architecture with no cloud dependency.

**Platform**: macOS 14.0+
**Language**: Swift 5.9+
**Database**: SQLite3 (via native C API)

## Build Commands

### Quick Build & Run (Development)
```bash
cd StickyNotesMac
./build.sh              # Compiles and launches the app
```

### Full Build (Creates .app bundle)
```bash
./build.sh              # From project root
# Creates build/Sticky Notes.app
```

### Manual Compilation
```bash
cd StickyNotesMac
swiftc -o StickyNotesApp \
  DesignSystem.swift \
  StickyNotesAppMain.swift \
  Models/*.swift \
  Views/*.swift \
  ViewModels/*.swift \
  Services/*.swift \
  Documents/*.swift \
  -parse-as-library \
  -framework SwiftUI -framework AppKit -framework Foundation -framework Network \
  -lsqlite3
```

### Windows Companion
```bash
pip install -r requirements.txt
python windows_companion.py
```

## Architecture

### MVVM Pattern
- **Models**: `StickyNote` struct with RTF data storage (`NoteColor` enum, color conversions)
- **ViewModels**: `NotesViewModel` (ObservableObject) coordinates between database, sync, and views
- **Views**: SwiftUI views (`ContentView`, `NoteEditorView`, `RichTextEditor`, `FormattingToolbar`)

### Data Flow
```
User Action → View → NotesViewModel → DatabaseManager (SQLite)
                              ↓
                         SyncManager → WebSocketServer
                              ↓
                    Windows Companion (WebSocket client)
```

### Key Components

**DatabaseManager** (Services/DatabaseManager.swift)
- Singleton managing SQLite database at `~/Documents/Sticky Notes/sticky_notes.sqlite`
- Thread-safe operations via dedicated dispatch queue
- Handles transactions, migrations (plain text → RTF)
- Stores notes as BLOB (RTF data) with metadata

**SyncManager** (Services/SyncManager.swift)
- Orchestrates network sync via WebSocketServer
- Broadcasts local changes, handles incoming note updates
- Conflict resolution: newer `modifiedAt` timestamp wins
- Uses NotificationCenter to notify ViewModel of external changes

**WebSocketServer** (Services/WebSocketServer.swift)
- NWListener-based HTTP server on local network
- Bonjour service discovery (`_stickynotes._tcp`)
- JSON protocol for note updates: `{"type": "note_update", "action": "create|update|delete", "note": {...}}`
- Manages multiple client connections

**WindowsNotesParser** (Services/WindowsNotesParser.swift)
- Parses Windows `plum.sqlite` database
- Converts Windows FileTime (100ns intervals since 1601) to Unix timestamps
- Exports/imports notes as JSON with ISO8601 dates

**Rich Text System**
- `RichTextEditor`: NSViewRepresentable wrapping NSTextView
- `FormattableTextView`: NSTextView subclass with Cmd+B/I/U shortcuts
- `FormattingToolbar`: SwiftUI toolbar for formatting (bold, italic, underline, headings, lists, code, highlight)
- RTF encoding/decoding via `NSAttributedString.DocumentType.rtf`

### Important Patterns

**State Synchronization**
- ViewModel uses `@Published` properties; views observe via `@StateObject`
- Database changes trigger NotificationCenter broadcasts (`.notesDidChange`)
- Sync updates use Combine publishers for reactive UI updates

**RTF Data Storage**
- Notes stored as RTF BLOB in SQLite
- Encoding: `StickyNote.encodeAttributedString()` converts NSAttributedString to RTF Data
- Decoding: `note.decodeAttributedString()` converts RTF Data back to NSAttributedString
- Migration helper converts legacy plain text to RTF automatically

**Thread Safety**
- DatabaseManager uses serial queue for all operations
- SyncManager uses dedicated dispatch queue for incoming note processing
- UI updates always dispatched to main queue

### File Structure
```
StickyNotesMac/
├── Models/           # StickyNote, NoteColor
├── Views/            # SwiftUI views (ContentView, NoteEditorView, etc.)
├── ViewModels/       # NotesViewModel
├── Services/         # DatabaseManager, SyncManager, WebSocketServer, WindowsNotesParser
├── Documents/        # NotesDocument (FileDocument for JSON export)
└── DesignSystem.swift # Spacing, colors, button styles
```

### Network Sync Protocol

**Outbound** (macOS → Windows):
```json
{
  "type": "note_update",
  "action": "create|update|delete",
  "note": {
    "id": "uuid",
    "attributedText": "<base64 RTF data>",
    "createdAt": "2026-01-12T10:30:00Z",
    "modifiedAt": "2026-01-12T10:30:00Z",
    "color": "Yellow"
  }
}
```

**Conflict Resolution**: Compare `modifiedAt` timestamps; newer wins

### Windows Companion

- Python app using `websocket-client` library
- Reads from `plum.sqlite` at Windows Sticky Notes LocalState path
- Auto-discovers macOS app via Bonjour or manual IP entry
- Bidirectional sync: sends local changes, receives macOS changes

## Database Location

- **macOS**: `~/Documents/Sticky Notes/sticky_notes.sqlite`
- **Windows**: `%LocalAppData%\Packages\Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe\LocalState\plum.sqlite`

## Common Tasks

**Add new note property**:
1. Add to `StickyNote` struct (Models/StickyNote.swift)
2. Update DatabaseManager schema migration
3. Update SQLite `INSERT/SELECT` statements
4. Update WebSocket protocol if syncing

**Modify sync protocol**:
- Change `WebSocketServer.broadcastNote()` message format
- Update `WindowsNotesParser` to handle new fields
- Ensure ISO8601 date encoding/decoding for dates

**Debug RTF issues**:
- Check console for "DEBUG:" log statements in encode/decode functions
- Verify RTF data is not empty before encoding
- Test with simple text vs complex formatting
