# Sticky Notes Sync - macOS & Windows

A native macOS Sticky Notes app that syncs with Windows Sticky Notes over local WiFi.

## Features

- **Read Windows Sticky Notes**: Import notes from Windows `plum.sqlite` database
- **Cross-Platform Sync**: Real-time sync over local WiFi network
- **No Cloud Required**: All data stays on your local network
- **Modern UI**: Clean, minimal interface matching macOS design
- **Color Support**: All 5 Windows Sticky Notes colors
- **Search**: Full-text search across all notes
- **File Export/Import**: JSON export for backup or manual sync

## Installation

### macOS App

1. Open `StickyNotesMac/` in Xcode
2. Build and run the app
3. Grant network permissions when prompted

### Windows Companion

```bash
# Install dependencies
pip install -r requirements.txt

# Run companion app
python windows_companion.py
```

## Usage

### Initial Setup

1. **On macOS**:
   - Launch the Sticky Notes app
   - Click "Start Sync" in the toolbar menu
   - The app will start listening for connections on your local network

2. **On Windows**:
   - Run `windows_companion.py` with Python
   - It will automatically detect and connect to your macOS app
   - Windows Sticky Notes will sync automatically

### Importing Windows Notes

1. Copy `plum.sqlite` from Windows:
   ```
   C:\Users\YourName\AppData\Local\Packages\Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe\LocalState\plum.sqlite
   ```

2. In macOS app:
   - Click the menu (•••) in toolbar
   - Select "Import from Windows"
   - Choose the `plum.sqlite` file

### Network Sync

- Both Mac and Windows must be on the same WiFi network
- The macOS app acts as a WebSocket server
- Windows app connects and syncs in real-time
- Changes on either device sync instantly

### Manual Sync (Alternative)

If network sync isn't available:

1. **Export** from macOS: Menu → Export Notes
2. Transfer file via USB, cloud, etc.
3. **Import** on other device

## Sync Architecture

### Protocol (JSON)

```json
{
  "type": "note_update",
  "action": "create|update|delete",
  "note": {
    "id": "uuid",
    "text": "note content",
    "color": "Yellow",
    "createdAt": "2026-01-12T10:30:00Z",
    "modifiedAt": "2026-01-12T10:30:00Z"
  }
}
```

### Network

- **macOS**: WebSocket server on port 8080 (auto-discoverable via Bonjour)
- **Windows**: WebSocket client that connects to macOS app
- **Data transfer**: JSON over local WiFi

## Troubleshooting

### Connection Issues

- Ensure both devices are on same WiFi network
- Check firewall settings on macOS (System Preferences → Security → Firewall)
- Verify macOS app is running with "Start Sync" enabled

### Import Issues

- Make sure you're using the correct `plum.sqlite` file
- Close Windows Sticky Notes before copying the file
- Try copying both `plum.sqlite` and `plum.sqlite-wal`

### Windows Companion

- Run as Administrator if you get permission errors
- Install Visual C++ Redistributable if you get DLL errors
- Check Python version (requires 3.7+)

## Privacy & Security

- All data stays on your local network
- No internet connection required
- No cloud storage or accounts needed
- Notes stored locally in SQLite database

## Requirements

### macOS
- macOS 14.0+
- Xcode 15.0+
- Swift 5.9+

### Windows
- Windows 10/11
- Python 3.7+
- Sticky Notes app (Windows built-in)

## File Locations

### macOS
- Notes database: `~/Documents/Sticky Notes/sticky_notes.sqlite`
- App data: `~/Library/Application Support/StickyNotesMac/`

### Windows
- Original notes: `%LocalAppData%\Packages\Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe\LocalState\plum.sqlite`
- Companion cache: Same directory as script

## Development

### Building from Source

**macOS**:
```bash
cd StickyNotesMac
xcodebuild -project StickyNotesMac.xcodeproj -scheme StickyNotesMac build
```

**Windows**:
```bash
pip install -r requirements.txt
python windows_companion.py
```

## License

MIT License - Feel free to use and modify

## Contributing

Contributions welcome! Please feel free to submit issues or pull requests.
