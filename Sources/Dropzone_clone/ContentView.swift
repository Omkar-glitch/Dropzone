import SwiftUI
import AppKit
import UniformTypeIdentifiers
import Quartz

struct ContentView: View {
    @EnvironmentObject var sharedModel: SharedModel
    let appDelegate: AppDelegate
    @State private var isDragging = false
    @State private var selectedFiles: Set<URL> = []
    @State private var viewMode: ViewMode = .list
    @State private var lastSelectedIndex: Int? = nil
    @State private var quickLookCoordinator = QuickLookCoordinator()
    
    enum ViewMode: String, CaseIterable {
        case list = "List"
        case grid = "Grid"
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Dropped Files")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                // Show selected count if any
                if !selectedFiles.isEmpty {
                    Text("\(selectedFiles.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // View Mode Toggle (no text label)
                Picker(selection: $viewMode, label: EmptyView()) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.icon)
                            .tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .labelsHidden()
                .frame(width: 60)
                
                Button(action: {
                    selectedFiles.removeAll()
                    lastSelectedIndex = nil
                    sharedModel.clearAll()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(sharedModel.files.isEmpty)
                .help("Clear All")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            
            Divider()
            
            // File list
            if sharedModel.files.isEmpty {
                VStack {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 50))
                        .foregroundColor(.secondary)
                    Text("Drop files here")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    Text("or drag files to other apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                VStack(spacing: 0) {
                    // Multi-file drag area (shows when multiple files selected)
                    if selectedFiles.count > 0 {
                        HStack(spacing: 12) {
                            // Selection info
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("\(selectedFiles.count) selected")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            
                            Spacer()
                            
                            // Action buttons
                            Button(action: {
                                // Copy selected files to clipboard
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.writeObjects(Array(selectedFiles) as [NSURL])
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Copy files")
                            
                            Button(action: {
                                // Show selected files in Finder
                                NSWorkspace.shared.activateFileViewerSelecting(Array(selectedFiles))
                            }) {
                                Image(systemName: "folder")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Show in Finder")
                            
                            Button(action: {
                                // Clear selection
                                selectedFiles.removeAll()
                                lastSelectedIndex = nil
                            }) {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Clear selection")
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        
                        Divider()
                    }
                    
                    if viewMode == .list {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(sharedModel.files.enumerated()), id: \.element) { index, url in
                                FileRow(url: url, appDelegate: appDelegate, isSelected: selectedFiles.contains(url))
                                    .environmentObject(sharedModel)
                                    .help("Right-click for options. Cmd+Click to select individual, Shift+Click for range")
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        handleSelection(url: url, index: index)
                                    }
                            }
                            }
                            .padding(.vertical, 8)
                        }
                        .onTapGesture {
                            // Clicking on empty space deselects all
                            selectedFiles.removeAll()
                            lastSelectedIndex = nil
                        }
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 12) {
                                ForEach(Array(sharedModel.files.enumerated()), id: \.element) { index, url in
                                    GridFileItem(url: url, appDelegate: appDelegate, isSelected: selectedFiles.contains(url))
                                        .environmentObject(sharedModel)
                                        .onTapGesture {
                                            handleSelection(url: url, index: index)
                                        }
                                }
                            }
                            .padding()
                        }
                        .onTapGesture {
                            // Clicking on empty space deselects all
                            selectedFiles.removeAll()
                            lastSelectedIndex = nil
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .frame(width: 300, height: 400)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
        }
        .onDrop(of: [.data], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
        .background(
            QuickLookView(
                onSpacePressed: {
                    if !selectedFiles.isEmpty {
                        toggleQuickLook()
                    }
                },
                onArrowKey: { direction in
                    handleArrowKey(direction)
                },
                onShiftDelete: {
                    deleteSelectedFiles()
                }
            )
        )
    }
    
    func toggleQuickLook() {
        guard let panel = QLPreviewPanel.shared() else { return }
        
        if panel.isVisible {
            // Disable focus retention when closing
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
               let contentWindow = appDelegate.contentWindow as? FocusRetainingWindow {
                contentWindow.shouldRetainFocus = false
            }
            panel.orderOut(nil)
        } else {
            showQuickLook()
        }
    }
    
    func showQuickLook() {
        guard let panel = QLPreviewPanel.shared() else { return }
        
        quickLookCoordinator.fileURLs = Array(selectedFiles)
        quickLookCoordinator.selectedIndex = 0
        quickLookCoordinator.onNavigate = { newIndex in
            // Note: Can't use [weak self] since ContentView is a struct
            // This closure is called by QuickLookCoordinator which doesn't create retain cycles
        }
        
        panel.dataSource = quickLookCoordinator
        panel.delegate = quickLookCoordinator
        
        // Enable focus retention on our window
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate,
           let contentWindow = appDelegate.contentWindow as? FocusRetainingWindow {
            contentWindow.shouldRetainFocus = true
        }
        
        // Show Quick Look
        panel.makeKeyAndOrderFront(nil)
    }
    
    func handleArrowKey(_ direction: QuickLookHostingView.ArrowDirection) {
        guard !sharedModel.files.isEmpty else { return }
        
        
        let currentIndex: Int
        if let selected = selectedFiles.first,
           let index = sharedModel.files.firstIndex(of: selected) {
            currentIndex = index
        } else {
            currentIndex = 0
        }
        
        var newIndex = currentIndex
        switch direction {
        case .up, .left:
            newIndex = max(0, currentIndex - 1)
        case .down, .right:
            newIndex = min(sharedModel.files.count - 1, currentIndex + 1)
        }
        
        
        if newIndex != currentIndex || selectedFiles.isEmpty {
            selectedFiles = [sharedModel.files[newIndex]]
            lastSelectedIndex = newIndex
            
            // If Quick Look is open, update it to show the new file
            if let panel = QLPreviewPanel.shared(), panel.isVisible {
                quickLookCoordinator.fileURLs = [sharedModel.files[newIndex]]
                quickLookCoordinator.selectedIndex = 0
                panel.reloadData()
                panel.updateController()
            }
        }
    }
    
    func deleteSelectedFiles() {
        
        guard !selectedFiles.isEmpty else {
            return
        }
        
        // Find the index of the first selected file
        let firstSelected = selectedFiles.first!
        guard let currentIndex = sharedModel.files.firstIndex(of: firstSelected) else {
            return
        }
        
        
        // Remove all selected files
        for file in selectedFiles {
            sharedModel.removeFile(file)
        }
        selectedFiles.removeAll()
        
        
        // Select the next item if available
        if !sharedModel.files.isEmpty {
            let newIndex = min(currentIndex, sharedModel.files.count - 1)
            selectedFiles = [sharedModel.files[newIndex]]
            lastSelectedIndex = newIndex
            
            // If Quick Look is open, update it to show the new file
            if let panel = QLPreviewPanel.shared(), panel.isVisible {
                quickLookCoordinator.fileURLs = [sharedModel.files[newIndex]]
                quickLookCoordinator.selectedIndex = 0
                panel.reloadData()
                panel.updateController()
            }
        } else {
            // No files left, close Quick Look if open
            if let panel = QLPreviewPanel.shared(), panel.isVisible {
                panel.orderOut(nil)
            }
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) {
        sharedModel.handleDrop(providers: providers)
    }
    
    func handleSelection(url: URL, index: Int) {
        let modifiers = NSEvent.modifierFlags
        
        if modifiers.contains(.command) {
            // Cmd+Click: Toggle individual selection
            if selectedFiles.contains(url) {
                selectedFiles.remove(url)
            } else {
                selectedFiles.insert(url)
            }
            lastSelectedIndex = index
        } else if modifiers.contains(.shift), let lastIndex = lastSelectedIndex {
            // Shift+Click: Select range
            let start = min(lastIndex, index)
            let end = max(lastIndex, index)
            
            // Add all files in range to selection
            for i in start...end {
                if i < sharedModel.files.count {
                    selectedFiles.insert(sharedModel.files[i])
                }
            }
        } else {
            // Regular click: Select only this file
            if selectedFiles.contains(url) && selectedFiles.count == 1 {
                // Clicking on already selected single file deselects it
                selectedFiles.removeAll()
                lastSelectedIndex = nil
            } else {
                selectedFiles.removeAll()
                selectedFiles.insert(url)
                lastSelectedIndex = index
            }
        }
    }
    
}

struct FileRow: View {
    let url: URL
    let appDelegate: AppDelegate
    var isSelected: Bool = false
    @EnvironmentObject var sharedModel: SharedModel
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: fileIcon(for: url))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Text(fileSize(for: url))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                sharedModel.removeFile(url)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .opacity(0.7)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isDragging ? Color.accentColor.opacity(0.2) : (isSelected ? Color.accentColor.opacity(0.1) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isDragging ? Color.accentColor : (isSelected ? Color.accentColor.opacity(0.5) : Color.clear), lineWidth: isDragging ? 2 : 1)
        )
        .contentShape(Rectangle()) // Make entire row draggable
        .onDrag {
            // Mark as dragging
            withAnimation(.easeInOut(duration: 0.2)) {
                isDragging = true
            }
            appDelegate.startDraggingSession()
            
            // Provide the file URL for dragging
            return NSItemProvider(object: url as NSURL)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DragSessionEnded"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isDragging = false
            }
        }
        .contextMenu {
            // Quick Look - just open the file
            Button(action: {
                NSWorkspace.shared.open(url)
            }) {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            
            
            // Reveal in Finder (this works as Quick Look alternative)
            Button(action: {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }) {
                Label("Show in Finder (Space for Quick Look)", systemImage: "eye")
            }
            
            // Copy Path
            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(url.path, forType: .string)
            }) {
                Label("Copy Path", systemImage: "doc.on.doc")
            }
            
            // Copy File
            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([url as NSURL])
            }) {
                Label("Copy File", systemImage: "doc.on.clipboard")
            }
            
            Divider()
            
            // Open With...
            Menu("Open With...") {
                ForEach(getAppsForFile(url: url), id: \.self) { app in
                    Button(action: {
                        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
                    }) {
                        Text(app.deletingPathExtension().lastPathComponent)
                    }
                }
            }
            
            Divider()
            
            // Remove from list
            Button(action: {
                sharedModel.removeFile(url)
            }) {
                Label("Remove from Dropzone", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
    }
    
    func getAppsForFile(url: URL) -> [URL] {
        let apps = NSWorkspace.shared.urlsForApplications(toOpen: url)
        return Array(apps.prefix(5)) // Limit to 5 apps
    }
    
    func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff":
            return "photo.fill"
        case "mp4", "mov", "avi", "mkv":
            return "video.fill"
        case "mp3", "wav", "aiff", "m4a":
            return "music.note"
        case "zip", "rar", "7z", "tar", "gz":
            return "doc.zipper"
        case "txt", "md", "rtf":
            return "doc.text.fill"
        case "swift", "js", "py", "java", "c", "cpp", "h":
            return "chevron.left.forwardslash.chevron.right"
        default:
            return "doc.fill"
        }
    }
    
    func fileSize(for url: URL) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes?[.size] as? Int64 {
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: size)
        }
        return "Unknown size"
    }
}

// Grid View Item
struct GridFileItem: View {
    let url: URL
    let appDelegate: AppDelegate
    var isSelected: Bool = false
    @EnvironmentObject var sharedModel: SharedModel
    @State private var isDragging = false
    @State private var thumbnail: NSImage?
    
    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail or icon
            ZStack {
                if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                } else {
                    Image(systemName: fileIcon(for: url))
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                }
            }
            .frame(width: 60, height: 60)
            
            Text(url.lastPathComponent)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 70)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDragging ? Color.accentColor.opacity(0.2) : (isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDragging ? Color.accentColor : (isSelected ? Color.accentColor.opacity(0.5) : Color.clear), lineWidth: isDragging ? 2 : 1)
        )
        .onAppear {
            loadThumbnail()
        }
        .contentShape(Rectangle())
        .onDrag {
            withAnimation(.easeInOut(duration: 0.2)) {
                isDragging = true
            }
            appDelegate.startDraggingSession()
            
            return NSItemProvider(object: url as NSURL)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DragSessionEnded"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isDragging = false
            }
        }
        .contextMenu {
            Button("Open") {
                NSWorkspace.shared.open(url)
            }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.path, forType: .string)
            }
            Divider()
            Button("Remove") {
                sharedModel.removeFile(url)
            }
            .foregroundColor(.red)
        }
    }
    
    func loadThumbnail() {
        DispatchQueue.global(qos: .background).async {
            if let image = NSImage(contentsOf: url) {
                DispatchQueue.main.async {
                    self.thumbnail = image
                }
            } else {
                // Try to get icon from the system
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                DispatchQueue.main.async {
                    self.thumbnail = icon
                }
            }
        }
    }
    
    func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.fill"
        case "jpg", "jpeg", "png", "gif", "bmp", "tiff":
            return "photo.fill"
        case "mp4", "mov", "avi", "mkv":
            return "video.fill"
        case "mp3", "wav", "aiff", "m4a":
            return "music.note"
        case "zip", "rar", "7z", "tar", "gz":
            return "doc.zipper"
        default:
            return "doc.fill"
        }
    }
}
