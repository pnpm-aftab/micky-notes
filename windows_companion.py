#!/usr/bin/env python3
"""
Windows Sticky Notes Companion App
Syncs Windows Sticky Notes with macOS app over local network
"""

import sqlite3
import json
import socket
import threading
import time
import os
from pathlib import Path
from datetime import datetime
import tkinter as tk
from tkinter import ttk
import win32crypt
import sys
import uuid
import base64

class WindowsNotesParser:
    """Parse Windows Sticky Notes from plum.sqlite"""
    
    def __init__(self):
        self.plum_path = self.find_plum_sqlite()
    
    def find_plum_sqlite(self):
        """Find plum.sqlite location on Windows"""
        local_app_data = os.environ.get('LOCALAPPDATA', '')
        plum_path = Path(local_app_data) / "Packages" / "Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe" / "LocalState" / "plum.sqlite"
        
        if plum_path.exists():
            return str(plum_path)
        
        # Fallback to legacy location
        roaming = os.environ.get('APPDATA', '')
        legacy_path = Path(roaming) / "Microsoft" / "Sticky Notes" / "StickyNotes.snt"
        
        if legacy_path.exists():
            return str(legacy_path)
        
        return None
    
    def parse_notes(self):
        """Parse notes from plum.sqlite"""
        if not self.plum_path:
            return []
        
        notes = []
        
        try:
            conn = sqlite3.connect(self.plum_path)
            cursor = conn.cursor()
            
            # Try different table structures
            tables = ['Note', 'Notes', 'StickyNotes']
            
            for table in tables:
                try:
                    cursor.execute(f"PRAGMA table_info({table})")
                    columns = [col[1] for col in cursor.fetchall()]
                    
                    # Find text column
                    text_col = None
                    for col in ['Text', 'Content', 'Body', 'NoteText']:
                        if col in columns:
                            text_col = col
                            break
                    
                    if text_col:
                        cursor.execute(f"SELECT {text_col} FROM {table}")
                        rows = cursor.fetchall()
                        
                        for row in rows:
                            note_text = row[0] if row[0] else ""
                            if note_text:
                                # Generate a proper UUID string
                                note_uuid = str(uuid.uuid4())

                                # Convert plain text to RTF format
                                rtf_text = "{\\rtf1\\ansi\\ansicpg1252\\deff0\\nouicompat\\deflang1033\\viewkind4\\uc1\\pard\\f0\\fs20 " + note_text + "\\par}"

                                # Encode RTF text as bytes, then base64
                                rtf_bytes = rtf_text.encode('utf-8')
                                rtf_base64 = base64.b64encode(rtf_bytes).decode('ascii')

                                # Use UTC timezone for ISO8601 format
                                now = datetime.utcnow()
                                notes.append({
                                    'id': note_uuid,
                                    'attributedText': rtf_base64,  # Send as base64-encoded RTF data
                                    'createdAt': now.isoformat() + 'Z',
                                    'modifiedAt': now.isoformat() + 'Z',
                                    'color': 'Yellow'
                                })
                        break
                        
                except sqlite3.OperationalError:
                    continue
            
            conn.close()
            
        except Exception as e:
            print(f"Error parsing notes: {e}")
        
        return notes


class TCPClient:
    """TCP client to communicate with macOS app"""

    def __init__(self, host='localhost', port=None):
        self.host = host
        self.port = port
        self.socket = None
        self.connected = False
        self.on_message = None
        self.on_connected = None  # Callback when connected
        self.actual_port = None
        self.receive_thread = None

    def connect(self):
        """Connect to macOS app - try common ports if not specified"""
        if self.port:
            ports_to_try = [self.port]
        else:
            ports_to_try = [8080, 3000, 5000, 8000, 9000]

        for port in ports_to_try:
            try:
                print(f"Trying to connect to {self.host}:{port}...")
                self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                self.socket.settimeout(5)
                self.socket.connect((self.host, port))

                self.connected = True
                self.actual_port = port
                print(f"✅ Successfully connected on port {port}")

                # Start receiving messages
                self.receive_thread = threading.Thread(target=self._receive_messages, daemon=True)
                self.receive_thread.start()

                # Trigger callback to notify that we're connected
                if self.on_connected:
                    self.on_connected()

                return

            except Exception as e:
                print(f"Failed to connect on port {port}: {e}")
                self.connected = False
                if self.socket:
                    self.socket.close()
                continue

        print("Could not connect to macOS app on any port")

    def _receive_messages(self):
        """Receive messages from server"""
        while self.connected:
            try:
                data = self.socket.recv(65536)
                if not data:
                    print("Disconnected from server")
                    self.connected = False
                    break

                # Try to parse as JSON
                try:
                    message = json.loads(data.decode('utf-8'))
                    if self.on_message:
                        self.on_message(message)
                except json.JSONDecodeError:
                    pass

            except socket.timeout:
                continue
            except Exception as e:
                print(f"Error receiving message: {e}")
                self.connected = False
                break

    def send_note(self, note, action):
        """Send note update to macOS app"""
        if not self.connected or not self.socket:
            return

        message = {
            'type': 'note_update',
            'action': action,
            'note': note
        }

        try:
            data = json.dumps(message).encode('utf-8')
            # Prefix message with 4-byte length prefix
            length_prefix = len(data).to_bytes(4, byteorder='big')
            self.socket.sendall(length_prefix + data)
        except Exception as e:
            print(f"Error sending message: {e}")
            self.connected = False

    def disconnect(self):
        """Disconnect from server"""
        self.connected = False
        if self.socket:
            self.socket.close()
        print("Disconnected")


class SyncManager:
    """Manage sync between Windows and macOS"""

    def __init__(self, mac_host=None):
        self.parser = WindowsNotesParser()
        self.client = TCPClient(host=mac_host or 'localhost')
        self.last_sync = None
        self.notes_cache = {}

        # Setup message handler
        self.client.on_message = self.handle_message

        # Setup auto-sync on connection
        self.client.on_connected = self.auto_sync
    
    def auto_sync(self):
        """Automatically sync notes when connected"""
        print("🔄 Auto-syncing Windows notes to macOS...")
        self.sync_to_macos()

    def handle_message(self, data):
        """Handle incoming message from macOS"""
        if data.get('type') == 'note_update':
            action = data.get('action')
            note = data.get('note', {})

            if action == 'create':
                self.create_note_on_windows(note)
            elif action == 'update':
                self.update_note_on_windows(note)
            elif action == 'delete':
                self.delete_note_on_windows(note)
    
    def create_note_on_windows(self, note):
        """Create note in Windows Sticky Notes"""
        # This is complex as Windows Sticky Notes doesn't have a public API
        # For now, we'll just store in cache
        note_id = note.get('id')
        if note_id:
            self.notes_cache[note_id] = note
            print(f"Received note from macOS: {note.get('text', '')[:50]}...")
    
    def update_note_on_windows(self, note):
        """Update note in Windows Sticky Notes"""
        note_id = note.get('id')
        if note_id in self.notes_cache:
            self.notes_cache[note_id] = note
    
    def delete_note_on_windows(self, note):
        """Delete note from cache"""
        note_id = note.get('id')
        if note_id in self.notes_cache:
            del self.notes_cache[note_id]
    
    def sync_to_macos(self):
        """Sync Windows notes to macOS"""
        notes = self.parser.parse_notes()
        
        for note in notes:
            self.client.send_note(note, 'create')
        
        self.last_sync = datetime.now()
        print(f"Synced {len(notes)} notes to macOS")


class TrayIcon:
    """System tray icon for Windows companion app"""

    def __init__(self, mac_host=None):
        self.root = tk.Tk()
        self.root.withdraw()  # Hide main window

        self.sync_manager = SyncManager(mac_host=mac_host)
        self.is_connected = False

        self.create_tray_icon()
    
    def create_tray_icon(self):
        """Create system tray icon"""
        # Use hidden window as tray
        self.root.title("Sticky Notes Sync")
        
        # Create popup menu
        menu = tk.Menu(self.root, tearoff=0)
        menu.add_command(label="Connect to macOS", command=self.connect)
        menu.add_command(label="Disconnect", command=self.disconnect)
        menu.add_separator()
        menu.add_command(label="Sync Now", command=self.sync_now)
        menu.add_separator()
        menu.add_command(label="Status: Disconnected", command=self.show_status)
        menu.add_separator()
        menu.add_command(label="Exit", command=self.exit_app)
        
        # Note: Windows requires actual tray icon library
        # This is a simplified version
        print("Sticky Notes Sync Companion running...")
        print("Right-click system tray icon for options")
    
    def connect(self):
        """Connect to macOS app"""
        self.sync_manager.client.connect()
        self.is_connected = self.sync_manager.client.connected
        print("Attempting to connect to macOS app...")
    
    def disconnect(self):
        """Disconnect from macOS app"""
        self.sync_manager.client.disconnect()
        self.is_connected = False
        print("Disconnected")
    
    def sync_now(self):
        """Sync notes now"""
        if self.is_connected:
            self.sync_manager.sync_to_macos()
            print("Sync complete")
        else:
            print("Not connected to macOS app")
    
    def show_status(self):
        """Show connection status"""
        status = "Connected" if self.is_connected else "Disconnected"
        print(f"Status: {status}")
        if self.sync_manager.last_sync:
            print(f"Last sync: {self.sync_manager.last_sync}")
    
    def exit_app(self):
        """Exit application"""
        self.disconnect()
        self.root.quit()
    
    def run(self):
        """Run the application"""
        # Auto-connect on startup
        self.connect()
        
        # Keep running
        self.root.mainloop()


if __name__ == "__main__":
    # Get Mac IP from command line argument or use default
    mac_ip = sys.argv[1] if len(sys.argv) > 1 else None

    if mac_ip:
        print(f"Connecting to Mac at: {mac_ip}")
    else:
        print("No Mac IP provided. Usage: python windows_companion.py <MAC_IP>")
        print("Trying localhost...")

    try:
        app = TrayIcon(mac_host=mac_ip)
        app.run()
    except KeyboardInterrupt:
        print("\nShutting down...")
