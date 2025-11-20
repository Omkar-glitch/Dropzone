import AppKit

/// Custom window class that maintains keyboard focus even when Quick Look is shown
class FocusRetainingWindow: NSWindow {
    var shouldRetainFocus = false
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
    
    override func resignKey() {
        // If we should retain focus, immediately become key again
        if shouldRetainFocus {
            DispatchQueue.main.async {
                self.makeKey()
            }
        } else {
            super.resignKey()
        }
    }
}
