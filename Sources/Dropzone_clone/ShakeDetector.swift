import Cocoa

protocol ShakeDetectorDelegate: AnyObject {
    func shakeDetectorDidDetectShake(_ detector: ShakeDetector)
}

class ShakeDetector {
    weak var delegate: ShakeDetectorDelegate?
    
    private var timer: Timer?
    private var lastLocation: NSPoint = .zero
    private var recentMoves: [CGFloat] = []
    private let historySize = 10
    private let minShakeVelocity: CGFloat = 10.0 // Lowered from 15.0
    private let shakeThreshold: Int = 3 // Lowered from 4
    
    // Direction of the last significant movement
    // 1 for right/down, -1 for left/up, 0 for none
    private var lastDirectionX: Int = 0
    private var directionChangesX: Int = 0
    
    private var isRunning = false
    
    func startMonitoring() {
        guard !isRunning else { return }
        isRunning = true
        
        lastLocation = NSEvent.mouseLocation
        
        // Check at 60Hz
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.checkMouseMovement()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        resetDetection()
    }
    
    private func resetDetection() {
        recentMoves.removeAll()
        lastDirectionX = 0
        directionChangesX = 0
    }
    
    private var stationaryFrames: Int = 0
    
    private func checkMouseMovement() {
        let currentLocation = NSEvent.mouseLocation
        let dx = currentLocation.x - lastLocation.x
        
        // Check if moving fast enough to be part of a shake
        if abs(dx) > minShakeVelocity {
            stationaryFrames = 0
            let currentDirectionX = dx > 0 ? 1 : -1
            
            if lastDirectionX != 0 && currentDirectionX != lastDirectionX {
                // Direction changed!
                directionChangesX += 1
                print("[ShakeDetector] Direction change: \(directionChangesX)")
            }
            
            lastDirectionX = currentDirectionX
        } else {
            // Movement is slow (or stopped)
            stationaryFrames += 1
            
            // Only reset if we've been stationary for a while (e.g., 10 frames = ~160ms)
            // This allows velocity to pass through zero during a direction change
            if stationaryFrames > 10 {
                if directionChangesX > 0 {
                    print("[ShakeDetector] Resetting due to inactivity")
                }
                directionChangesX = 0
                lastDirectionX = 0 // Reset direction too so next move counts as new
            }
        }
        
        lastLocation = currentLocation
        
        if directionChangesX >= shakeThreshold {
            // Shake detected!
            print("[ShakeDetector] Shake threshold reached!")
            delegate?.shakeDetectorDidDetectShake(self)
            
            // Reset to prevent multiple triggers for the same shake
            directionChangesX = 0
            stationaryFrames = 0
        }
    }
}
