import SwiftUI
import Foundation
import AppKit
import UniformTypeIdentifiers

struct FileEntry: Identifiable, Equatable, Hashable {
    let id = UUID()
    let url: URL
    let addedDate: Date
    
    static func == (lhs: FileEntry, rhs: FileEntry) -> Bool {
        lhs.url == rhs.url
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

class SharedModel: ObservableObject {
    @Published var files: [URL] = []
    @Published var fileEntries: [FileEntry] = []
    
    // Smart Features Settings
    @AppStorage("maxRecentItems") var maxRecentItems: Int = 50
    @AppStorage("autoExpireDays") var autoExpireDays: Int = 7
    @AppStorage("preventDuplicates") var preventDuplicates: Bool = true
    @AppStorage("autoCleanup") var autoCleanup: Bool = true
    
    init() {
        cleanupOldEntries()
    }
    
    func addFile(_ url: URL) {
        // Check for duplicates
        if preventDuplicates && files.contains(url) {
            // Move to top if already exists
            files.removeAll { $0 == url }
        }
        
        // Add to beginning
        files.insert(url, at: 0)
        fileEntries.insert(FileEntry(url: url, addedDate: Date()), at: 0)
        
        // Enforce max items limit
        if files.count > maxRecentItems {
            files = Array(files.prefix(maxRecentItems))
            fileEntries = Array(fileEntries.prefix(maxRecentItems))
        }
        
        // Schedule cleanup
        if autoCleanup {
            cleanupOldEntries()
        }
    }
    
    func removeFile(_ url: URL) {
        files.removeAll { $0 == url }
        fileEntries.removeAll { $0.url == url }
    }
    
    func cleanupOldEntries() {
        guard autoCleanup && autoExpireDays > 0 else { return }
        
        let cutoffDate = Date().addingTimeInterval(-Double(autoExpireDays) * 24 * 60 * 60)
        
        // Remove entries older than cutoff date
        fileEntries = fileEntries.filter { entry in
            entry.addedDate > cutoffDate
        }
        
        // Update files array to match
        files = fileEntries.map { $0.url }
    }
    
    func clearAll() {
        files.removeAll()
        fileEntries.removeAll()
        cleanupTempFiles()
    }
    
    /// Clean up temporary files created from Photos/Safari drops
    func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DropzoneClone", isDirectory: true)
        
        do {
            if FileManager.default.fileExists(atPath: tempDir.path) {
                try FileManager.default.removeItem(at: tempDir)
            }
        } catch {
        }
    }
    
    func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            
            // 1. Check for File Promises (e.g. from Photos, Safari)
            // Check for both modern and legacy promise types
            if provider.hasItemConformingToTypeIdentifier("com.apple.NSFilePromiseItemMetaData") || 
               provider.hasItemConformingToTypeIdentifier("com.apple.pasteboard.promised-file-url") {
                let promiseType = provider.hasItemConformingToTypeIdentifier("com.apple.NSFilePromiseItemMetaData") ? "com.apple.NSFilePromiseItemMetaData" : "com.apple.pasteboard.promised-file-url"
                
                provider.loadItem(forTypeIdentifier: promiseType, options: nil) { [weak self] (item, error) in
                    if let error = error {
                        return
                    }
                    
                    // The item should be the NSFilePromiseReceiver
                    guard let receiver = item as? NSFilePromiseReceiver else {
                        return
                    }
                    
                    // Create a temp URL to write to
                    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DropzoneClone", isDirectory: true)
                    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
                    
                    receiver.receivePromisedFiles(atDestination: tempDir, options: [:], operationQueue: OperationQueue.main) { (fileURL, error) in
                        if let error = error {
                            return
                        }
                        DispatchQueue.main.async {
                            self?.addFile(fileURL)
                        }
                    }
                }
                continue
            }
            
            // 2. Check for Standard File URLs
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] (item, error) in
                    if let error = error {
                        return
                    }
                    
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else {
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self?.addFile(url)
                    }
                }
                continue
            }
            
            // 3. Check for plain URLs (that might be file URLs)
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                    if let error = error {
                        return
                    }
                    
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else {
                        return
                    }
                    
                    if url.isFileURL {
                        DispatchQueue.main.async {
                            self?.addFile(url)
                        }
                    }
                }
            }
            
            // 4. Check for Images (e.g. direct image drag from Safari/Photos without file promise?)
            // NOTE: Photos app provides BOTH file promise AND image types, but attempting to load
            // the image directly will fail with permission errors. The file promise handler above
            // should have already handled it with continue, so we only reach here for non-promised images.
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] (data, error) in
                    if let error = error {
                        return
                    }
                    
                    guard let data = data else {
                        return
                    }
                    
                    // Save to temp file
                    let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DropzoneClone", isDirectory: true)
                    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
                    
                    // Try to guess extension or default to png
                    let filename = "DroppedImage-\(UUID().uuidString).png" // Simple fallback
                    let fileURL = tempDir.appendingPathComponent(filename)
                    
                    do {
                        try data.write(to: fileURL)
                        DispatchQueue.main.async {
                            self?.addFile(fileURL)
                        }
                    } catch {
                    }
                }
                continue
            }
        }
    }
}
