import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Custom NSView that properly handles drag-and-drop including Photos app file promises
class DragDropHostingView: NSView {
    var onDrop: (([NSItemProvider]) -> Void)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupDragAndDrop()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDragAndDrop()
    }
    
    private func setupDragAndDrop() {
        // Register for ALL drag types to ensure Photos app promises are accepted
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("com.apple.NSFilePromiseItemMetaData"),
            NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url"),
            NSPasteboard.PasteboardType("public.file-url"),
            NSPasteboard.PasteboardType("public.image"),
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.png"),
            .string, // For URLs as strings
        ])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onDragEntered?()
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        onDragExited?()
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        
        let pasteboard = sender.draggingPasteboard
        
        // 1. First, try to read standard file URLs (from Finder)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            let fileURLs = urls.filter { $0.isFileURL }
            if !fileURLs.isEmpty {
                // Create NSItemProviders directly from the file URLs (preserves original path)
                let providers = fileURLs.compactMap { NSItemProvider(contentsOf: $0) }
                onDrop?(providers)
                return true
            }
        }
        
        // 2. Try to handle file promises (from Photos, Safari)
        if let filePromiseReceivers = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver] {
            
            for receiver in filePromiseReceivers {
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DropzoneClone", isDirectory: true)
                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
                
                receiver.receivePromisedFiles(atDestination: tempDir, options: [:], operationQueue: OperationQueue.main) { (fileURL, error) in
                    if let error = error {
                        return
                    }
                    
                    // Call onDrop with a provider wrapping this file URL
                    let provider = NSItemProvider(contentsOf: fileURL)!
                    DispatchQueue.main.async {
                        self.onDrop?([provider])
                    }
                }
            }
            return true
        }
        
        // 3. Fallback: Convert pasteboard items to NSItemProviders for other types
        var providers: [NSItemProvider] = []
        
        if let items = pasteboard.pasteboardItems {
            for item in items {
                let types = item.types
                
                // Create NSItemProvider for each item
                let provider = NSItemProvider()
                
                // Register all available types
                for type in types {
                    if let data = item.data(forType: type) {
                        provider.registerDataRepresentation(forTypeIdentifier: type.rawValue, visibility: .all) { completion in
                            completion(data, nil)
                            return nil
                        }
                    }
                }
                
                providers.append(provider)
            }
        }
        
        if !providers.isEmpty {
            onDrop?(providers)
            return true
        }
        
        return false
    }
}

/// SwiftUI wrapper for DragDropHostingView
struct DragDropView: NSViewRepresentable {
    @Binding var isTargeted: Bool
    let onDrop: ([NSItemProvider]) -> Void
    
    func makeNSView(context: Context) -> DragDropHostingView {
        let view = DragDropHostingView()
        view.onDrop = onDrop
        view.onDragEntered = {
            DispatchQueue.main.async {
                isTargeted = true
            }
        }
        view.onDragExited = {
            DispatchQueue.main.async {
                isTargeted = false
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: DragDropHostingView, context: Context) {
        nsView.onDrop = onDrop
        nsView.onDragEntered = {
            DispatchQueue.main.async {
                isTargeted = true
            }
        }
        nsView.onDragExited = {
            DispatchQueue.main.async {
                isTargeted = false
            }
        }
    }
}
