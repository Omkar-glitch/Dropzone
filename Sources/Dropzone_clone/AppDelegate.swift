import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem!
    var contentWindow: NSWindow?
    let sharedModel = SharedModel()
    var eventMonitor: Any?
    var dropzoneWindow: NSWindow?
    var isDraggingFromApp = false
    var dragMonitorTimer: Timer?
    var dragSessionTimer: Timer?
    var consecutiveValidDragTicks: Int = 0
    
    func startDraggingSession() {
        isDraggingFromApp = true
        
        // Start monitoring for mouse up to end the drag session
        dragSessionTimer?.invalidate()
        dragSessionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            // Check if mouse button is released
            if NSEvent.pressedMouseButtons == 0 {
                self.endDraggingSession()
            }
        }
    }
    
    func endDraggingSession() {
        isDraggingFromApp = false
        dragSessionTimer?.invalidate()
        dragSessionTimer = nil
        
        // Notify views that drag has ended
        NotificationCenter.default.post(name: NSNotification.Name("DragSessionEnded"), object: nil)
    }
    var consecutiveInvalidTicks: Int = 0
    
    var shakeDetector: ShakeDetector?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Configure app to appear in menu bar only
        NSApp.setActivationPolicy(.accessory)
        
        // Create the status bar item
        self.statusBarItem = NSStatusBar.system.statusItem(withLength: CGFloat(NSStatusItem.variableLength))
        
        if let button = self.statusBarItem.button {
            button.image = NSImage(systemSymbolName: "tray.fill", accessibilityDescription: "Dropzone Clone")
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Create the content window
        setupContentWindow()
        
        // Set up drag monitoring
        setupDragMonitoring()
        
        // Set up shake detector
        shakeDetector = ShakeDetector()
        shakeDetector?.delegate = self
        shakeDetector?.startMonitoring()
    }
    
    func setupContentWindow() {
        contentWindow = FocusRetainingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        contentWindow?.title = "Dropzone"
        contentWindow?.isReleasedWhenClosed = false
        
        // Set window level to floating so it stays above Quick Look and maintains focus
        contentWindow?.level = .floating
        contentWindow?.hidesOnDeactivate = false
        
        // Prevent window from becoming key when Quick Look opens
        contentWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let hostingController = NSHostingController(
            rootView: ContentView(appDelegate: self).environmentObject(sharedModel)
        )
        contentWindow?.contentViewController = hostingController
    }
    
    func setupDragMonitoring() {
        // Poll every 80ms to check for file drag operations
        // We keep this for the "hover" behavior if desired, or we can rely solely on shake
        // The user asked for "shake to open... instead of just dragging", which might mean
        // they want to REPLACE the auto-open behavior or ADD to it.
        // For now, I'll keep the existing check but make it less aggressive or just keep it as is
        // and let shake be an alternative trigger.
        dragMonitorTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            self?.checkForFileDrag()
        }
    }
    
    func checkForFileDrag() {
        // Only check when mouse button is pressed (active drag)
        let pressedButtons = NSEvent.pressedMouseButtons
        if pressedButtons != 0 {
        }
        guard pressedButtons != 0 else {
            // Mouse released - hide window and reset
            if dropzoneWindow?.isVisible == true {
                hideDropzoneWindow()
            }
            consecutiveValidDragTicks = 0
            consecutiveInvalidTicks = 0
            return
        }
        
        // Don't interfere with internal drags or when content window is visible
        guard !isDraggingFromApp, contentWindow?.isVisible != true else {
            consecutiveValidDragTicks = 0
            return
        }
        
        // We still check for valid files to update state, but maybe we don't auto-open
        // unless it's Finder? Or maybe we rely on Shake?
        // Let's keep the existing logic for Finder auto-open as a convenience,
        // but Shake will work EVERYWHERE.
        
        // Check the drag pasteboard
        let pasteboard = NSPasteboard(name: .drag)
        let hasValidFiles = hasValidFileDragContent(pasteboard: pasteboard)
        
        if hasValidFiles {
            consecutiveInvalidTicks = 0
            consecutiveValidDragTicks += 1
            
            // Only auto-open for Finder if that was the original behavior
            // User requested "Shake to Open" instead of just dragging.
            // Disabling auto-open on drag/hover.
            // if isFinderActive() {
            //    if consecutiveValidDragTicks >= 2 && dropzoneWindow?.isVisible != true {
            //        showDropzoneWindow()
            //    }
            // }
        } else {
            consecutiveValidDragTicks = 0
            consecutiveInvalidTicks += 1
            
            if consecutiveInvalidTicks >= 2 && dropzoneWindow?.isVisible == true {
                hideDropzoneWindow()
            }
        }
    }
    
    func isFinderActive() -> Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return false
        }
        return frontApp.bundleIdentifier == "com.apple.finder"
    }
    
    func hasValidFileDragContent(pasteboard: NSPasteboard) -> Bool {
        // Debug: Print pasteboard types
        if let types = pasteboard.types {
        } else {
            return false
        }
        
        // 1. Try to read actual file URLs (Best case)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            if urls.contains(where: { $0.isFileURL }) {
                return true
            }
        }
        
        // 2. Check for file promises (Safari, etc.)
        if let types = pasteboard.types {
            if types.contains(NSPasteboard.PasteboardType("com.apple.NSFilePromiseItemMetaData")) ||
               types.contains(NSPasteboard.PasteboardType("NSFilePromiseReceiver")) {
                return true
            }
            
            // 3. Universal Fallback: Check for filenames or generic file URLs
            // Some apps might just put a string path or "public.file-url" without standard Cocoa classes
            if types.contains(NSPasteboard.PasteboardType.fileURL) ||
               types.contains(NSPasteboard.PasteboardType("public.file-url")) {
                return true
            }
            
            // Check for promised file URL (Photos app specific)
            if types.contains(NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url")) {
                return true
            }
            
            // 4. Last resort: If we are shaking, we probably want to drop SOMETHING.
            // If there is ANY content on the drag pasteboard, let's open.
            // But let's filter out purely internal drags if possible.
            if !types.isEmpty {
                // Maybe exclude if ONLY generic types?
                return true
            }
        }
        
        return false
    }
    
    func showDropzoneWindow() {
        // Only show if not already visible and content window is not shown
        if dropzoneWindow?.isVisible == true || contentWindow?.isVisible == true {
            return
        }
        
        if dropzoneWindow == nil {
            // Create a borderless, transparent window for better appearance
            dropzoneWindow = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 180),
                styleMask: [.nonactivatingPanel, .hudWindow],
                backing: .buffered,
                defer: false)
            dropzoneWindow?.isReleasedWhenClosed = false
            dropzoneWindow?.level = .floating
            dropzoneWindow?.backgroundColor = NSColor.clear
            dropzoneWindow?.isOpaque = false
            dropzoneWindow?.hasShadow = true
            dropzoneWindow?.contentViewController = NSHostingController(
                rootView: DropzoneView(isFloating: true).environmentObject(sharedModel)
            )
        }
        
        // Position window near mouse cursor
        let mouseLocation = NSEvent.mouseLocation
        dropzoneWindow?.setFrameTopLeftPoint(NSPoint(x: mouseLocation.x + 20, y: mouseLocation.y - 20))
        dropzoneWindow?.makeKeyAndOrderFront(nil)
    }
    
    func hideDropzoneWindow() {
        dropzoneWindow?.orderOut(nil)
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        // Detect right-click
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            // Show quit menu on right-click
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            
            if let button = statusBarItem.button {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
            }
            return
        }
        
        // Left-click - toggle window
        if contentWindow?.isVisible == true {
            closeContentWindow()
        } else {
            showContentWindow()
        }
    }
    
    func showContentWindow() {
        guard let button = statusBarItem.button, let window = contentWindow else { return }
        
        // Position window below status item
        let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
        let windowWidth = window.frame.width
        let x = buttonFrame.midX - windowWidth / 2
        let y = buttonFrame.minY - window.frame.height - 5
        
        window.setFrameOrigin(NSPoint(x: x, y: y))
        window.makeKeyAndOrderFront(nil)
        
        // Monitor for clicks outside the window
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.contentWindow, window.isVisible else { return }
            
            // Don't close if we're dragging or if clicking on status item
            if self.isDraggingFromApp {
                return
            }
            
            let clickLocation = NSEvent.mouseLocation
            let windowFrame = window.frame
            let buttonFrame = self.statusBarItem.button?.window?.convertToScreen(self.statusBarItem.button?.frame ?? .zero) ?? .zero
            
            if !windowFrame.contains(clickLocation) && !buttonFrame.contains(clickLocation) {
                self.closeContentWindow()
            }
        }
    }
    
    func closeContentWindow() {
        contentWindow?.orderOut(nil)
        
        // Remove event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        dragMonitorTimer?.invalidate()
        shakeDetector?.stopMonitoring()
    }
}

extension AppDelegate: ShakeDetectorDelegate {
    func shakeDetectorDidDetectShake(_ detector: ShakeDetector) {
        // Shake detected!
        
        // Check if we are dragging files
        
        // 1. Must have mouse button pressed
        guard NSEvent.pressedMouseButtons != 0 else {
            return
        }
        
        // 2. Must not be dragging FROM our app (unless we want to allow dropping back in?)
        guard !isDraggingFromApp else {
            return
        }
        
        // 3. Must have valid files on drag pasteboard
        let pasteboard = NSPasteboard(name: .drag)
        if hasValidFileDragContent(pasteboard: pasteboard) {
            showDropzoneWindow()
        } else {
        }
    }
}


