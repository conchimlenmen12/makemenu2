import Foundation
import UIKit

class ESPManager: NSObject {
    static let shared = ESPManager()

    private var displayLink: CADisplayLink?
    private var isRunning = false

    override init() {
        super.init()
    }

    func startESPLoop() {
        globallogger.log("[ESPManager] ESP loop disabled (kernel memory reads cause crashes)")
    }

    func stopESPLoop() {
        guard isRunning else { return }

        isRunning = false

        DispatchQueue.main.async {
            self.displayLink?.invalidate()
            self.displayLink = nil
        }

        globallogger.log("[ESPManager] ESP loop stopped")
    }

    @objc private func updateESPFrame() {
        guard isEspEnabled() else {
            if isRunning {
                stopESPLoop()
            }
            return
        }

        updateESP()
    }
}
