import Foundation
import UIKit

// Bridge to get Module_Base from Objective-C
@_silgen_name("getUnityFrameworkBase")
func getUnityFrameworkBase() -> UInt64

struct Enemy {
    var screenHeadPos: CGPoint
    var screenFootPos: CGPoint
    var currentHP: Int32
    var maxHP: Int32
}

// MARK: - ESP Offsets (from scr tipa - relative to Module_Base)
let OFF_GAMEFACADE_TYPEINFO: UInt64 = 0xC3299C8
let OFF_GAMEFACADE_STATIC: UInt64 = 0xB8
let OFF_GAMEFACADE_CURRENTMATCH: UInt64 = 0x8
let OFF_MATCH_MATCH: UInt64 = 0x90
let OFF_MATCH_PLAYERDICT: UInt64 = 0x148
let OFF_DICT_COUNT: UInt64 = 0x20
let OFF_DICT_ENTRIES: UInt64 = 0x18
let OFF_DICT_ENTRY_STRIDE: UInt64 = 24
let OFF_DICT_ENTRY_VALUE: UInt64 = 16

let OFF_PLAYER_POSITION: UInt64 = 0x60
let OFF_PLAYER_HEAD: UInt64 = 0x1A8
let OFF_PLAYER_HP: UInt64 = 0x208
let OFF_PLAYER_MAX_HP: UInt64 = 0x20C

let OFF_MATCH_CAMERA_MGR: UInt64 = 0xD8
let OFF_CAMERA_MGR_MAIN: UInt64 = 0x20
let OFF_CAMERA_VIEWMATRIX: UInt64 = 0x10
let OFF_VIEWMATRIX_DATA: UInt64 = 0x80

// MARK: - ESP State
private var espDrawLayer: CALayer?
private var lastLogTime = Date()

// MARK: - Public API
func isEspEnabled() -> Bool {
    return UserDefaults.standard.bool(forKey: "espFF_enabled")
}

func setEspEnabled(_ enabled: Bool) {
    let wasEnabled = isEspEnabled()
    if wasEnabled != enabled {
        UserDefaults.standard.set(enabled, forKey: "espFF_enabled")
        let state = enabled ? "ENABLED" : "DISABLED"
        globallogger.log("[ESP] ESP \(state)")
    }
}

func initializeESP() -> Bool {
    globallogger.log("[ESP] Initialized")
    return true
}

func updateESP() {
    guard isEspEnabled() else { return }

    do {
        try detectAndDrawEnemies()
    } catch {
        let now = Date()
        if now.timeIntervalSince(lastLogTime) > 2 {
            globallogger.log("[ESP] Error: \(error)")
            lastLogTime = now
        }
    }
}

// MARK: - Main Detection & Drawing
private func detectAndDrawEnemies() throws {
    let moduleBase = getUnityFrameworkBase()
    globallogger.log("[ESP] ModuleBase: 0x\(String(moduleBase, radix: 16))")
    guard moduleBase > 0x100000000 else {
        globallogger.log("[ESP] Module base invalid")
        return
    }

    // Read GameFacade
    let gameFacadeTypeInfo = ds_kread64(moduleBase + OFF_GAMEFACADE_TYPEINFO)
    globallogger.log("[ESP] GameFacadeTypeInfo: 0x\(String(gameFacadeTypeInfo, radix: 16))")
    guard gameFacadeTypeInfo > 0x100000000 else {
        globallogger.log("[ESP] GameFacadeTypeInfo invalid")
        return
    }

    let gameFacadeStatic = ds_kread64(gameFacadeTypeInfo + OFF_GAMEFACADE_STATIC)
    globallogger.log("[ESP] GameFacadeStatic: 0x\(String(gameFacadeStatic, radix: 16))")
    guard gameFacadeStatic > 0x100000000 else {
        globallogger.log("[ESP] GameFacadeStatic invalid")
        return
    }

    let matchGame = ds_kread64(gameFacadeStatic + OFF_GAMEFACADE_CURRENTMATCH)
    globallogger.log("[ESP] MatchGame: 0x\(String(matchGame, radix: 16))")
    guard matchGame > 0x100000000 else {
        globallogger.log("[ESP] MatchGame invalid (not in match)")
        return
    }

    // Read Match object
    let match = ds_kread64(matchGame + OFF_MATCH_MATCH)
    globallogger.log("[ESP] Match: 0x\(String(match, radix: 16))")
    guard match > 0x100000000 else {
        globallogger.log("[ESP] Match invalid")
        return
    }

    // Read player dictionary
    let playerDict = ds_kread64(match + OFF_MATCH_PLAYERDICT)
    globallogger.log("[ESP] PlayerDict: 0x\(String(playerDict, radix: 16))")
    guard playerDict > 0x100000000 else {
        globallogger.log("[ESP] PlayerDict invalid")
        return
    }

    let dictCount = Int(ds_kread32(playerDict + OFF_DICT_COUNT))
    globallogger.log("[ESP] DictCount: \(dictCount)")
    guard dictCount > 0 && dictCount < 200 else {
        globallogger.log("[ESP] DictCount invalid")
        return
    }

    let entriesArr = ds_kread64(playerDict + OFF_DICT_ENTRIES)
    globallogger.log("[ESP] EntriesArr: 0x\(String(entriesArr, radix: 16))")
    guard entriesArr > 0x100000000 else {
        globallogger.log("[ESP] EntriesArr invalid")
        return
    }

    // Get camera matrix
    let cameraMgr = ds_kread64(matchGame + OFF_MATCH_CAMERA_MGR)
    globallogger.log("[ESP] CameraMgr: 0x\(String(cameraMgr, radix: 16))")
    guard cameraMgr > 0x100000000 else {
        globallogger.log("[ESP] CameraMgr invalid")
        return
    }

    let cameraMain = ds_kread64(cameraMgr + OFF_CAMERA_MGR_MAIN)
    globallogger.log("[ESP] CameraMain: 0x\(String(cameraMain, radix: 16))")
    guard cameraMain > 0x100000000 else {
        globallogger.log("[ESP] CameraMain invalid")
        return
    }

    let viewMatrixAddr = ds_kread64(cameraMain + OFF_CAMERA_VIEWMATRIX)
    globallogger.log("[ESP] ViewMatrixAddr: 0x\(String(viewMatrixAddr, radix: 16))")
    guard viewMatrixAddr > 0x100000000 else {
        globallogger.log("[ESP] ViewMatrixAddr invalid")
        return
    }

    // Read projection matrix (16 floats)
    var matrix = [Float](repeating: 0, count: 16)
    var buffer = [UInt8](repeating: 0, count: 64)
    ds_kread(viewMatrixAddr + OFF_VIEWMATRIX_DATA, &buffer, 64)
    buffer.withUnsafeBytes { ptr in
        let floats = ptr.bindMemory(to: Float.self)
        for i in 0..<16 {
            matrix[i] = floats[i]
        }
    }

    let screenW = UIScreen.main.bounds.width
    let screenH = UIScreen.main.bounds.height

    DispatchQueue.main.async {
        setupESPLayer()
    }

    globallogger.log("[ESP] Processing \(dictCount) players...")
    var processedCount = 0

    // Process each player
    for i in 0..<min(dictCount, 100) {
        let entAddr = entriesArr + OFF_DICT_ENTRIES + UInt64(i) * OFF_DICT_ENTRY_STRIDE
        let playerAddr = ds_kread64(entAddr + OFF_DICT_ENTRY_VALUE)
        guard playerAddr > 0x100000000 else { continue }

        processedCount += 1

        // Read player HP
        let hp = Int32(bitPattern: ds_kread32(playerAddr + OFF_PLAYER_HP))
        guard hp > 0 else { continue }

        let maxHp = Int32(bitPattern: ds_kread32(playerAddr + OFF_PLAYER_MAX_HP))

        // Read positions
        let headAddr = ds_kread64(playerAddr + OFF_PLAYER_HEAD)
        guard headAddr > 0x100000000 else { continue }

        let headPos = readVector3(headAddr + OFF_PLAYER_POSITION)
        let footPos = readVector3(playerAddr + OFF_PLAYER_POSITION)

        // Project to screen
        guard let headScreen = worldToScreen(headPos, matrix, Float(screenW), Float(screenH)),
              let footScreen = worldToScreen(footPos, matrix, Float(screenW), Float(screenH)) else {
            continue
        }

        DispatchQueue.main.async {
            drawESPLine(from: headScreen, to: footScreen)
        }
    }

    globallogger.log("[ESP] Processed: \(processedCount) players")
}

// MARK: - Helper Functions
private func readVector3(_ addr: UInt64) -> Vector3 {
    guard addr > 0 else { return Vector3() }
    var buffer = [UInt8](repeating: 0, count: 12)
    ds_kread(addr, &buffer, 12)
    return buffer.withUnsafeBytes { ptr -> Vector3 in
        let floats = ptr.bindMemory(to: Float.self)
        return Vector3(x: floats[0], y: floats[1], z: floats[2])
    }
}

private func worldToScreen(_ worldPos: Vector3, _ matrix: [Float], _ screenW: Float, _ screenH: Float) -> CGPoint? {
    let x = worldPos.x
    let y = worldPos.y
    let z = worldPos.z

    // Simple perspective projection (depth-based)
    // Objects farther away (larger z) appear smaller
    let perspective = 500.0 / max(z + 1.0, 0.1)

    let screenX = (screenW / 2.0) + (x * Float(perspective))
    let screenY = (screenH / 2.0) - (y * Float(perspective))

    guard screenX >= 0 && screenX < screenW && screenY >= 0 && screenY < screenH else {
        return nil
    }

    return CGPoint(x: CGFloat(screenX), y: CGFloat(screenY))
}

private func setupESPLayer() {
    guard let window = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first?.windows
        .first(where: { $0.isKeyWindow }) else {
        return
    }

    if espDrawLayer == nil {
        espDrawLayer = CALayer()
        espDrawLayer?.frame = window.bounds
        espDrawLayer?.isOpaque = false
        window.layer.addSublayer(espDrawLayer!)
    }

    espDrawLayer?.sublayers?.removeAll()
}

private func drawESPLine(from: CGPoint, to: CGPoint) {
    guard let layer = espDrawLayer else { return }

    let lineLayer = CAShapeLayer()
    let path = UIBezierPath()
    path.move(to: from)
    path.addLine(to: to)

    lineLayer.path = path.cgPath
    lineLayer.strokeColor = UIColor.red.cgColor
    lineLayer.lineWidth = 1.5
    layer.addSublayer(lineLayer)
}
