import SwiftUI
import UniformTypeIdentifiers

struct DropzoneView: View {
    @EnvironmentObject var sharedModel: SharedModel
    @State private var isTargeted = false
    var isFloating: Bool = false
    
    var body: some View {
        if isFloating {
            // Compact floating view
            floatingView
        } else {
            // Regular view for the main window
            regularView
        }
    }
    
    var floatingView: some View {
        VStack(spacing: 12) {
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "arrow.down.doc")
                .font(.system(size: 40))
                .foregroundColor(isTargeted ? .white : Color.white.opacity(0.9))
                .animation(.easeInOut(duration: 0.2), value: isTargeted)
            
            Text("Drop files here")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Add to dropzone")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.8))
        }
        .frame(width: 280, height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isTargeted 
                    ? Color.accentColor.opacity(0.95) 
                    : Color.black.opacity(0.85)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isTargeted ? Color.white.opacity(0.5) : Color.white.opacity(0.2),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .scaleEffect(isTargeted ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isTargeted)
        .overlay(
            DragDropView(isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
        )
    }
    
    var regularView: some View {
        VStack {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 60))
                .foregroundColor(isTargeted ? .accentColor : .secondary)
                .animation(.easeInOut(duration: 0.2), value: isTargeted)
            
            Text("Drop files here")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 8)
            
            Text("Files will be added to your dropzone")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10, 5]))
                .foregroundColor(isTargeted ? .accentColor : .gray.opacity(0.3))
        )
        .padding()
        .overlay(
            DragDropView(isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }
        )
    }
    
    func handleDrop(providers: [NSItemProvider]) {
        sharedModel.handleDrop(providers: providers)
    }
}

struct DropzoneDelegate: DropDelegate {
    let handleDrop: ([NSItemProvider]) -> Void
    @Binding var isTargeted: Bool
    
    func validateDrop(info: DropInfo) -> Bool {
        // Try to get item providers for different types
        let itemCount = info.itemProviders(for: [.item]).count
        let contentCount = info.itemProviders(for: [.content]).count
        let imageCount = info.itemProviders(for: [.image]).count
        return true
    }
    
    func dropEntered(info: DropInfo) {
        isTargeted = true
    }
    
    func dropExited(info: DropInfo) {
        isTargeted = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        // Get ALL item providers without filtering by type
        // The NSItemProvider filtering was too restrictive - just get everything
        let allProviders = info.itemProviders(for: [.data])
        if allProviders.isEmpty {
            // Alternative: try to access the hasItemsConforming API
            let hasItems = info.hasItemsConforming(to: [.data])
        }
        handleDrop(allProviders)
        return true
    }
}
