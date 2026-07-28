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
        let running = isGameProcessRunning()
        let inMatch = isPlayerInMatch()

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

    // Check if Free Fire process is running
    private func isGameProcessRunning() -> Bool {
        guard ds_is_ready() else { return false }

        // Try to get FF process PID via sysctl
        let processName = "FreeFireMAX"

        var len: size_t = 0
        var mib: [Int32] = [
            CTL_KERN,
            KERN_PROC,
            KERN_PROC_ALL,
            0
        ]

        if sysctl(&mib, 4, nil, &len, nil, 0) != 0 {
            return false
        }

        guard len > 0 else { return false }

        var processes = [kinfo_proc](
            repeating: kinfo_proc(),
            count: len / MemoryLayout<kinfo_proc>.size
        )

        if sysctl(&mib, 4, &processes, &len, nil, 0) != 0 {
            return false
        }

        let processCount =
            len / MemoryLayout<kinfo_proc>.size

        for i in 0..<processCount {
            let process = processes[i]
            let name = String(
                cString: &process.kp_proc.p_comm.0
            )

            if name.contains(processName) {
                globallogger.log(
                    "[GameDetector] Found \(name) running"
                )
                return true
            }
        }

        return false
    }

    // Check if player is in active match (not lobby)
    private func isPlayerInMatch() -> Bool {
        guard ds_is_ready() else { return false }
        guard isGameRunning else { return false }

        // Simple check: try to read match game pointer
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

        // If we can read a valid match object, player is in game
        return true
    }
}