# Dropzone - macOS Menu Bar File Manager

A modern menu bar application for macOS that provides quick file management with shake-to-open functionality.

## Features

- **Shake to Open** - Shake your mouse while dragging files to open the dropzone
- **Universal File Drops** - Accept files from Finder, Photos, Safari, and any application
- **Keyboard Navigation** - Arrow keys, Space for Quick Look, Cmd+Delete to delete
- **Smart File Handling** - Finder files by reference, Photos/web files to temp directory
- **Clean Interface** - List and grid views with multi-select support
- **Auto Cleanup** - Automatic removal of old temporary files

## Installation

1. Download `Dropzone.app`
2. Move to `/Applications` folder
3. Double-click to launch
4. App will appear in menu bar with tray icon

## Usage

### Opening Dropzone
- **Shake Method**: Drag any file and shake your mouse left-right quickly
- **Menu Bar**: Click the tray icon to show/hide the window

### Keyboard Shortcuts
- **Arrow Keys** - Navigate through files
- **Space** - Toggle Quick Look preview
- **Cmd+Delete** - Delete selected file(s)
- **Right-click menu bar icon** - Quit application

### File Management
- **Drop files** from any application
- **Drag files out** to other applications
- **Multi-select** with Cmd-click or Shift-click
- **Context menu** with right-click for actions

## Requirements

- macOS 12.0 or later
- No external dependencies

## Building from Source

```bash
# Clone the repository
git clone https://github.com/YOUR_USERNAME/Dropzone_clone.git
cd Dropzone_clone

# Build release version
swift build -c release

# App bundle is created automatically
open Dropzone.app
```

## Technical Details

- Built with Swift and SwiftUI
- Uses AppKit for advanced drag-drop handling
- NSFilePromiseReceiver for Photos app integration
- Custom shake detection algorithm
- Floating window architecture

## License

Copyright © 2025. All rights reserved.

## Author

Created with ❤️ for efficient file management on macOS
