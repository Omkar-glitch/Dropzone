import SwiftUI
import AppKit
import UniformTypeIdentifiers

// Custom NSView for handling drag operations
class DraggableFileNSView: NSView, NSDraggingSource {
    var fileURL: URL
    var dragImage: NSImage?
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(frame: .zero)
        
        // Register for drag operations
        registerForDraggedTypes([.fileURL])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func mouseDown(with event: NSEvent) {
        // Create a dragging item
        let draggingItem = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        
        // Create drag image
        let dragImageSize = NSSize(width: 60, height: 60)
        dragImage = NSImage(size: dragImageSize)
        dragImage?.lockFocus()
        
        // Draw file icon
        let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
        icon.draw(in: NSRect(origin: .zero, size: dragImageSize))
        
        dragImage?.unlockFocus()
        
        draggingItem.setDraggingFrame(NSRect(origin: event.locationInWindow, size: dragImageSize), 
                                      contents: dragImage)
        
        // Begin dragging session
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }
    
    // NSDraggingSource protocol
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return [.copy, .link]
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // Dragging ended
    }
}

// SwiftUI wrapper for the draggable view
struct DraggableFileView: NSViewRepresentable {
    let url: URL
    let content: AnyView
    
    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        
        // Add the content view
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hostingView)
        
        // Add the draggable overlay
        let draggableView = DraggableFileNSView(fileURL: url)
        draggableView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(draggableView)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            draggableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            draggableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            draggableView.topAnchor.constraint(equalTo: containerView.topAnchor),
            draggableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        return containerView
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Update if needed
    }
}