import SwiftUI
import Quartz

/// Coordinator to handle Quick Look panel
class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var fileURLs: [URL] = []
    var selectedIndex: Int = 0
    var onNavigate: ((Int) -> Void)?
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return fileURLs.count
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard index < fileURLs.count else { return nil }
        return fileURLs[index] as NSURL
    }
    
    // Accept control of the preview panel
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }
    
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }
    
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        // Cleanup if needed
    }
}

/// NSView that can become first responder to handle keyboard events
class QuickLookHostingView: NSView {
    var onSpacePressed: (() -> Void)?
    var onArrowKey: ((ArrowDirection) -> Void)?
    var onShiftDelete: (() -> Void)?
    
    enum ArrowDirection {
        case up, down, left, right
    }
    
    override var acceptsFirstResponder: Bool { return true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Become first responder when added to window
        window?.makeFirstResponder(self)
    }
    
    override func mouseDown(with event: NSEvent) {
        // Ensure we become first responder on click
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
    
    override func keyDown(with event: NSEvent) {
        
        if event.keyCode == 49 { // Space key
            onSpacePressed?()
        } else if event.keyCode == 126 { // Up arrow
            onArrowKey?(.up)
        } else if event.keyCode == 125 { // Down arrow
            onArrowKey?(.down)
        } else if event.keyCode == 123 { // Left arrow
            onArrowKey?(.left)
        } else if event.keyCode == 124 { // Right arrow
            onArrowKey?(.right)
        } else if event.keyCode == 51 { // Delete key
            if event.modifierFlags.contains(.command) {
                onShiftDelete?()
            } else {
            }
        } else {
            super.keyDown(with: event)
        }
    }
}

/// SwiftUI wrapper for Quick Look handling
struct QuickLookView: NSViewRepresentable {
    let onSpacePressed: () -> Void
    let onArrowKey: (QuickLookHostingView.ArrowDirection) -> Void
    let onShiftDelete: () -> Void
    
    func makeNSView(context: Context) -> QuickLookHostingView {
        let view = QuickLookHostingView()
        view.onSpacePressed = onSpacePressed
        view.onArrowKey = onArrowKey
        view.onShiftDelete = onShiftDelete
        return view
    }
    
    func updateNSView(_ nsView: QuickLookHostingView, context: Context) {
        nsView.onSpacePressed = onSpacePressed
        nsView.onArrowKey = onArrowKey
        nsView.onShiftDelete = onShiftDelete
    }
}
