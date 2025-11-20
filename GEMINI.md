# GEMINI.md

## Project Overview

The goal of this project is to create a simple clone of the Dropzone application for macOS. The application should reside in the menu bar. When a user drags a file, a window should appear to accept the file. The dropped files should be stored and accessible by clicking the menu bar icon. From this list, the user should be able to drag the files to other applications.

## Current State

The application is partially functional. Here's a summary of what works and what doesn't:

### What Works

*   A menu bar icon is present.
*   Clicking the menu bar icon opens a window.
*   Files can be dropped into this window, and they appear in a list.
*   Files can be dragged from the list and dropped into other applications.

### What Doesn't Work

*   **The popover/window closes on drag:** When a file is dragged from the list, the window closes. This is the primary issue that has been the focus of the development efforts.
*   **No automatic dropzone:** The dropzone window does not automatically appear when a file is dragged from outside the application.

## Attempted Approaches

Several approaches were attempted to solve the issue of the popover closing on drag. All of them have failed. Here is a summary of the attempted approaches:

1.  **Custom `NSPopover` Subclass:** A custom subclass of `NSPopover` was created with an `isDragging` flag to prevent the popover from closing. This did not work as expected.
2.  **`Introspect` Library:** The `Introspect` library was used to get a reference to the underlying `NSPopover` and modify its behavior. This failed due to incorrect usage of the library.
3.  **Custom `NSWindow`:** A custom `NSWindow` was created to act as the popover. This also failed to solve the issue.
4.  **Custom `NSView`:** A custom `NSView` was created to be the content view of the popover. This also failed.

## Code

Here is the complete code for all the files in the project:

### `Package.swift`

```swift
// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "Dropzone_clone",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Dropzone_clone",
            dependencies: []
        ),
        .testTarget(
            name: "Dropzone_cloneTests",
            dependencies: ["Dropzone_clone"]
        ),
    ]
)
```

### `Sources/Dropzone_clone/App.swift`

```swift
import SwiftUI

@main
struct DropzoneCloneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

### `Sources/Dropzone_clone/AppDelegate.swift`

```swift
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var window: NSWindow!
    let sharedModel = SharedModel()

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Create the status bar item
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))

        if let button = self.statusBarItem.button {
            button.image = NSImage(systemSymbolName: "tray", accessibilityDescription: "Dropzone Clone")
            button.action = #selector(toggleWindow(_:))
        }

        // Create the window
        self.window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.borderless],
            backing: .buffered, defer: false)
        self.window.isReleasedWhenClosed = false
        self.window.contentViewController = NSHostingController(rootView: ContentView().environmentObject(sharedModel))
    }

    @objc func toggleWindow(_ sender: AnyObject?) {
        if self.window.isVisible {
            self.window.orderOut(sender)
        } else {
            if let button = self.statusBarItem.button {
                let buttonRect = button.window!.convertToScreen(button.frame)
                let screenRect = NSScreen.main!.frame
                let x = buttonRect.origin.x - (self.window.frame.width / 2) + (buttonRect.width / 2)
                let y = buttonRect.origin.y - self.window.frame.height - 10
                self.window.setFrameOrigin(NSPoint(x: x, y: y))
                self.window.makeKeyAndOrderFront(sender)
            }
        }
    }
}
```

### `Sources/Dropzone_clone/ContentView.swift`

```swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sharedModel: SharedModel

    var body: some View {
        VStack {
            Text("Dropped Files")
                .font(.headline)
                .padding()

            List(sharedModel.files, id: \.self) { url in
                Text(url.lastPathComponent)
                    .onDrag {
                        NSItemProvider(object: url as NSURL)
                    }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                for provider in providers {
                    provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { (data, error) in
                        if let data = data,
                           let path = NSString(data: data, encoding: 4),
                           let url = URL(string: path as String) {
                            DispatchQueue.main.async {
                                self.sharedModel.files.append(url)
                            }
                        }
                    }
                }
                return true
            }

            Spacer()
        }
    }
}
```

### `Sources/Dropzone_clone/DropzoneView.swift`

```swift
import SwiftUI

struct DropzoneView: View {
    @EnvironmentObject var sharedModel: SharedModel

    var body: some View {
        VStack {
            Text("Drop files here")
                .font(.headline)
                .padding()
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                provider.loadDataRepresentation(forTypeIdentifier: "public.file-url") { (data, error) in
                    if let data = data,
                       let path = NSString(data: data, encoding: 4),
                       let url = URL(string: path as String) {
                        DispatchQueue.main.async {
                            self.sharedModel.files.append(url)
                        }
                    }
                }
            }
            return true
        }
    }
}
```

### `Sources/Dropzone_clone/Dropzone_clone.swift`

```swift
// The Swift Programming Language
// https://docs.swift.org/swift-book

struct Dropzone_clone {
    var text = "Hello, World!"
}
```

### `Sources/Dropzone_clone/SharedModel.swift`

```swift
import SwiftUI

class SharedModel: ObservableObject {
    @Published var files: [URL] = []
}
```

### `Tests/Dropzone_cloneTests/Dropzone_cloneTests.swift`

```swift
import XCTest
@testable import Dropzone_clone

final class Dropzone_cloneTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Dropzone_clone().text, "Hello, World!")
    }
}
```