import Foundation

// Bridge to Objective-C GameLoopHook
@_silgen_name("startGameLoopHook")
func startGameLoopHook()

@_silgen_name("stopGameLoopHook")
func stopGameLoopHook()

@_silgen_name("updateGameLoopFeatures")
func updateGameLoopFeatures()

// MARK: - Game Loop Manager
class GameLoopManager {
    static let shared = GameLoopManager()

    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        guard ds_is_ready() else { return }

        isRunning = true
        startGameLoopHook()
        globallogger.log("[GameLoop] Started")
    }

    func stop() {
        guard isRunning else { return }

        isRunning = false
        stopGameLoopHook()
        globallogger.log("[GameLoop] Stopped")
    }

    func isActive() -> Bool {
        return isRunning
    }
}
