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
        guard !isRunning else { return }
        guard ds_is_ready() else {
            globallogger.log("[ESPManager] Darksword not ready, cannot start ESP")
            return
        }

        isRunning = true

        DispatchQueue.main.async {
            if self.displayLink == nil {
                self.displayLink = CADisplayLink(
                    target: self,
                    selector: #selector(self.updateESPFrame)
                )
                self.displayLink?.preferredFramesPerSecond = 30
                self.displayLink?.add(to: .main, forMode: .common)
            }
        }

        globallogger.log("[ESPManager] ESP loop started")
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
