import Foundation
import Combine
import Darwin

// MARK: - Game Detection (similar to scr tipa)

class GameDetector: ObservableObject {
    static let shared = GameDetector()

    @Published var isGameRunning = false
    @Published var isInMatch = false
    @Published var gameStatus = "Detecting..."

    private var detectionTimer: Timer?

    func startDetection() {
        guard detectionTimer == nil else { return }

        detectionTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            self?.updateGameStatus()
        }

        updateGameStatus()
    }

    func stopDetection() {
        detectionTimer?.invalidate()
        detectionTimer = nil
    }

    private func updateGameStatus() {
        let inMatch = isPlayerInMatch()
        let running = inMatch || canAccessGameMemory()

        DispatchQueue.main.async {
            self.isGameRunning = running
            self.isInMatch = inMatch

            if !running {
                self.gameStatus = "⚠️ Game not running"
            } else if !inMatch {
                self.gameStatus = "🏠 In lobby/menu"
            } else {
                self.gameStatus = "🎮 In match"
            }
        }
    }

    private func canAccessGameMemory() -> Bool {
        let moduleBase = getUnityFrameworkBase()
        return moduleBase > 0x100000000
    }


    // Check if player is in active match (not lobby)
    private func isPlayerInMatch() -> Bool {
        guard isGameRunning else { return false }

        let moduleBase = getUnityFrameworkBase()

        guard moduleBase > 0x100000000 else {
            return false
        }

        let gameFacadeTypeInfo =
            ds_kread64(moduleBase + 0xC3299C8)

        guard gameFacadeTypeInfo > 0x100000000 else {
            return false
        }

        let gameFacadeStatic =
            ds_kread64(gameFacadeTypeInfo + 0xB8)

        guard gameFacadeStatic > 0x100000000 else {
            return false
        }

        let matchGame =
            ds_kread64(gameFacadeStatic + 0x8)

        guard matchGame > 0x100000000 else {
            return false
        }

        let match =
            ds_kread64(matchGame + 0x90)

        guard match > 0x100000000 else {
            return false
        }

        return true
    }
}