import Foundation

// MARK: - Speed Offsets (from scr tipa)
let OFFSET_SPEED_MULTIPLIER: UInt64 = 0xAA0

// MARK: - Speed API
func isSpeedEnabled() -> Bool {
    return UserDefaults.standard.bool(forKey: "speedFF_enabled")
}

func setSpeedEnabled(_ enabled: Bool) {
    UserDefaults.standard.set(enabled, forKey: "speedFF_enabled")
    globallogger.log("[Speed] Speed \(enabled ? "ENABLED" : "DISABLED")")
}

func getSpeedValue() -> Float {
    let stored = UserDefaults.standard.float(forKey: "speedFF_value")
    return stored > 0 ? stored : 0.16
}

func setSpeedValue(_ value: Float) {
    UserDefaults.standard.set(max(0.1, min(value, 1.0)), forKey: "speedFF_value")
}

func applySpeed(toPlayer playerAddr: UInt64) {
    guard ds_is_ready() else { return }
    guard playerAddr > 0x100000000 else { return }

    let enabled = isSpeedEnabled()
    var multiplier = enabled ? getSpeedValue() : 1.0

    ds_kwrite(playerAddr + OFFSET_SPEED_MULTIPLIER, &multiplier, 4)
}

func updateSpeedForAllPlayers(_ players: [UInt64]) {
    for playerAddr in players {
        applySpeed(toPlayer: playerAddr)
    }
}
