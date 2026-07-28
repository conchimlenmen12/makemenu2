import Foundation

// Aimbot cho Free Fire qua Darksword kernel memory access
// Port từ scr tipa DrawView.mm, adapt để dùng Darksword API

// MARK: - Struct definitions
struct Vector3 {
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0
}

struct Quaternion {
    var x: Float = 0
    var y: Float = 0
    var z: Float = 0
    var w: Float = 1
}

// MARK: - Memory helpers qua Darksword
func readQuaternion(addr: UInt64) -> Quaternion {
    var buffer = [UInt8](repeating: 0, count: 16)
    ds_kread(addr, &buffer, UInt64(buffer.count))

    return buffer.withUnsafeBytes { ptr -> Quaternion in
        let floatPtr = ptr.bindMemory(to: Float.self)
        return Quaternion(
            x: floatPtr[0],
            y: floatPtr[1],
            z: floatPtr[2],
            w: floatPtr[3]
        )
    }
}

func writeQuaternion(addr: UInt64, quat: Quaternion) {
    var data = [quat.x, quat.y, quat.z, quat.w]
    ds_kwrite(addr, &data, UInt64(MemoryLayout<Float>.size * 4))
}

func readBool(addr: UInt64) -> Bool {
    let byte = ds_kread8(addr)
    return byte != 0
}

// MARK: - Quaternion math
func quaternionSlerp(from: Quaternion, to: Quaternion, t: Float) -> Quaternion {
    var t = t
    t = max(0, min(1, t))

    var dot = from.x * to.x + from.y * to.y + from.z * to.z + from.w * to.w

    var end = to
    if dot < 0 {
        end.x = -to.x
        end.y = -to.y
        end.z = -to.z
        end.w = -to.w
        dot = -dot
    }

    if dot > 0.9995 {
        var result = Quaternion()
        result.x = from.x + (end.x - from.x) * t
        result.y = from.y + (end.y - from.y) * t
        result.z = from.z + (end.z - from.z) * t
        result.w = from.w + (end.w - from.w) * t

        let len = sqrt(result.x * result.x + result.y * result.y + result.z * result.z + result.w * result.w)
        if len > 0 {
            result.x /= len
            result.y /= len
            result.z /= len
            result.w /= len
        }
        return result
    }

    dot = min(1, max(-1, dot))
    let theta0 = acos(dot)
    let theta = theta0 * t

    var qhat = Quaternion()
    qhat.x = end.x - from.x * dot
    qhat.y = end.y - from.y * dot
    qhat.z = end.z - from.z * dot
    qhat.w = end.w - from.w * dot

    let lenQhat = sqrt(qhat.x * qhat.x + qhat.y * qhat.y + qhat.z * qhat.z + qhat.w * qhat.w)
    if lenQhat > 0 {
        qhat.x /= lenQhat
        qhat.y /= lenQhat
        qhat.z /= lenQhat
        qhat.w /= lenQhat
    }

    let cosTheta = cos(theta)
    let sinTheta = sin(theta)

    return Quaternion(
        x: from.x * cosTheta + qhat.x * sinTheta,
        y: from.y * cosTheta + qhat.y * sinTheta,
        z: from.z * cosTheta + qhat.z * sinTheta,
        w: from.w * cosTheta + qhat.w * sinTheta
    )
}

// MARK: - Offsets (Free Fire)
let OFFSET_AIM_ROTATION: UInt64 = 0x5B4  // FFMAX
let OFFSET_AIM_ROTATION_AUX: UInt64 = 0x5C4  // FFMAX
let OFFSET_M_IS_SIGHTING: UInt64 = 0x748

// MARK: - Global state
private var aimbotState: (enabled: Bool, lastState: Bool) = (false, false)

// MARK: - Aimbot main function
func applyAimbot(playerAddr: UInt64, targetQuat: Quaternion, aimSpeed: Float, shouldAim: Bool) -> Bool {
    guard playerAddr > 0 && shouldAim else { return false }

    var aimSpeedVal = aimSpeed
    aimSpeedVal = max(0, min(100, aimSpeedVal))

    if aimSpeedVal < 99.99 {
        let t = aimSpeedVal < 1.0 ? 0.01 : sqrt(aimSpeedVal / 100.0)

        let currentRot = readQuaternion(addr: playerAddr + OFFSET_AIM_ROTATION)
        let smoothed = quaternionSlerp(from: currentRot, to: targetQuat, t: t)

        writeQuaternion(addr: playerAddr + OFFSET_AIM_ROTATION, quat: smoothed)
        writeQuaternion(addr: playerAddr + OFFSET_AIM_ROTATION_AUX, quat: smoothed)

        globallogger.log("[Aimbot] Smooth aim applied (speed: \(aimSpeedVal)%)")
    } else {
        // Instant snap
        writeQuaternion(addr: playerAddr + OFFSET_AIM_ROTATION, quat: targetQuat)
        writeQuaternion(addr: playerAddr + OFFSET_AIM_ROTATION_AUX, quat: targetQuat)

        globallogger.log("[Aimbot] Instant snap applied")
    }

    return true
}

func getPlayerAimRotation(playerAddr: UInt64) -> Quaternion {
    guard playerAddr > 0 else { return Quaternion() }
    return readQuaternion(addr: playerAddr + OFFSET_AIM_ROTATION)
}

func setPlayerAimRotation(playerAddr: UInt64, rot: Quaternion) -> Bool {
    guard playerAddr > 0 else { return false }
    writeQuaternion(addr: playerAddr + OFFSET_AIM_ROTATION, quat: rot)
    writeQuaternion(addr: playerAddr + OFFSET_AIM_ROTATION_AUX, quat: rot)
    return true
}

// MARK: - State management
func isAimbotEnabled() -> Bool {
    return UserDefaults.standard.bool(forKey: "aimbotFF_enabled")
}

func setAimbotEnabled(_ enabled: Bool) {
    let wasEnabled = isAimbotEnabled()
    if wasEnabled != enabled {
        UserDefaults.standard.set(enabled, forKey: "aimbotFF_enabled")
        let state = enabled ? "ENABLED" : "DISABLED"
        globallogger.log("[Aimbot] Aimbot \(state)")
    }
}

func getAimbotSpeed() -> Float {
    let speedInt = UserDefaults.standard.integer(forKey: "aimbotFF_speed")
    return speedInt > 0 ? Float(speedInt) : 50.0
}

// MARK: - Test function
func testAimbotFF() {
    globallogger.log("[Aimbot Test] Starting Darksword aimbot test...")
    globallogger.log("[Aimbot Test] Darksword is ready")
    globallogger.log("[Aimbot Test] Current aimbot: \(isAimbotEnabled() ? "ENABLED" : "DISABLED")")
    globallogger.log("[Aimbot Test] Current speed: \(Int(getAimbotSpeed()))%")
    globallogger.log("[Aimbot Test] Ready to integrate with game loop")
}
