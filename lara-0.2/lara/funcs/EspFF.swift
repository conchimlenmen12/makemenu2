import Foundation
import UIKit

struct Enemy {
    var position: Vector3
    var headPosition: Vector3
    var teamID: UInt32
    var isAlive: Bool
    var currentHP: Int32
    var maxHP: Int32
    var screenPos: CGPoint?
    var screenHeadPos: CGPoint?
}

// MARK: - ESP Offsets (from scr tipa FFMAX)
let OFFSET_GAME_FACADE_TYPE: UInt64 = 0x58CCFD0
let OFFSET_MATCH_GAME: UInt64 = 0x50
let OFFSET_MATCH_PLAYERS_DICT: UInt64 = 0x48
let OFFSET_PLAYER_POSITION: UInt64 = 0x60
let OFFSET_PLAYER_HEAD_NODE: UInt64 = 0xA8
let OFFSET_PLAYER_TEAM_ID: UInt64 = 0x150
let OFFSET_PLAYER_IS_ALIVE: UInt64 = 0x180
let OFFSET_PLAYER_CURRENT_HP: UInt64 = 0x1A0
let OFFSET_PLAYER_MAX_HP: UInt64 = 0x1A4

// MARK: - Camera offsets
let OFFSET_CAMERA_MAIN: UInt64 = 0x58C3BC0
let OFFSET_CAMERA_TRANSFORM: UInt64 = 0x60
let OFFSET_TRANSFORM_POSITION: UInt64 = 0x60
let OFFSET_CAMERA_PROJECTION_MATRIX: UInt64 = 0x100

// MARK: - ESP State
private var espEnabled = false
private var espDrawLayer: CALayer?
private var enemies: [Enemy] = []
private var myTeamID: UInt32 = 0

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
        espEnabled = enabled
    }
}

func initializeESP() -> Bool {
    guard ds_is_ready() else {
        globallogger.log("[ESP] Darksword not ready")
        return false
    }

    globallogger.log("[ESP] Initialized, ready to detect enemies")
    return true
}

func updateESP() {
    guard isEspEnabled() && ds_is_ready() else { return }

    DispatchQueue.global(qos: .userInitiated).async {
        detectEnemies()
        updateEnemyPositions()
    }
}

// MARK: - Enemy Detection
private func detectEnemies() {
    enemies.removeAll()

    guard let gameInstance = readGameInstance() else {
        globallogger.log("[ESP] Failed to read game instance")
        return
    }

    guard let matchGame = readMatchGame(gameInstance) else {
        globallogger.log("[ESP] Failed to read match game")
        return
    }

    guard let playersDict = readPlayersDictionary(matchGame) else {
        globallogger.log("[ESP] Failed to read players dictionary")
        return
    }

    let playerCount = Int(readDictionaryCount(playersDict))
    globallogger.log("[ESP] Found \(playerCount) players in game")

    for i in 0..<min(playerCount, 100) {
        if let playerAddr = readDictionaryEntry(playersDict, index: UInt64(i)) {
            if let enemy = readEnemyData(playerAddr) {
                enemies.append(enemy)
            }
        }
    }
}

// MARK: - Memory reading functions
private func readGameInstance() -> UInt64? {
    guard ds_is_ready() else { return nil }

    let typeinfoAddr = ds_kread64(OFFSET_GAME_FACADE_TYPE)
    guard typeinfoAddr > 0x100000000 else { return nil }

    return ds_kread64(typeinfoAddr)
}

private func readMatchGame(_ gameInstance: UInt64) -> UInt64? {
    guard gameInstance > 0 else { return nil }
    let addr = ds_kread64(gameInstance + OFFSET_MATCH_GAME)
    return addr > 0 ? addr : nil
}

private func readPlayersDictionary(_ matchGame: UInt64) -> UInt64? {
    guard matchGame > 0 else { return nil }
    let addr = ds_kread64(matchGame + OFFSET_MATCH_PLAYERS_DICT)
    return addr > 0 ? addr : nil
}

private func readDictionaryCount(_ dict: UInt64) -> UInt32 {
    guard dict > 0 else { return 0 }
    return ds_kread32(dict + 0x18)
}

private func readDictionaryEntry(_ dict: UInt64, index: UInt64) -> UInt64? {
    guard dict > 0 else { return nil }

    let entriesAddr = ds_kread64(dict + 0x20)
    guard entriesAddr > 0 else { return nil }

    let entryAddr = entriesAddr + (index * 32)
    let playerAddr = ds_kread64(entryAddr + 0x18)

    return playerAddr > 0 ? playerAddr : nil
}

private func readEnemyData(_ playerAddr: UInt64) -> Enemy? {
    guard playerAddr > 0 else { return nil }

    let position = readVector3(playerAddr + OFFSET_PLAYER_POSITION)
    let headPosition = readVector3(playerAddr + OFFSET_PLAYER_HEAD_NODE + OFFSET_TRANSFORM_POSITION)
    let teamID = ds_kread32(playerAddr + OFFSET_PLAYER_TEAM_ID)
    let isAlive = ds_kread8(playerAddr + OFFSET_PLAYER_IS_ALIVE) != 0
    let currentHP = Int32(bitPattern: ds_kread32(playerAddr + OFFSET_PLAYER_CURRENT_HP))
    let maxHP = Int32(bitPattern: ds_kread32(playerAddr + OFFSET_PLAYER_MAX_HP))

    return Enemy(
        position: position,
        headPosition: headPosition,
        teamID: teamID,
        isAlive: isAlive,
        currentHP: currentHP,
        maxHP: maxHP
    )
}

private func readVector3(_ addr: UInt64) -> Vector3 {
    guard addr > 0 else { return Vector3() }

    var buffer = [UInt8](repeating: 0, count: 12)
    ds_kread(addr, &buffer, 12)

    return buffer.withUnsafeBytes { ptr -> Vector3 in
        let floatPtr = ptr.bindMemory(to: Float.self)
        return Vector3(x: floatPtr[0], y: floatPtr[1], z: floatPtr[2])
    }
}

// MARK: - Screen Projection
private func updateEnemyPositions() {
    guard !enemies.isEmpty else { return }

    for i in 0..<enemies.count {
        enemies[i].screenPos = worldToScreen(enemies[i].position)
        enemies[i].screenHeadPos = worldToScreen(enemies[i].headPosition)
    }

    drawESP()
}

private func worldToScreen(_ worldPos: Vector3) -> CGPoint? {
    let screenWidth = UIScreen.main.bounds.width
    let screenHeight = UIScreen.main.bounds.height

    // Simplified projection: use perspective divide
    // In real scenario, would use camera matrix
    let perspective = 500.0 / (Double(worldPos.z) + 0.1)
    let screenX = screenWidth / 2 + CGFloat(Double(worldPos.x) * perspective)
    let screenY = screenHeight / 2 - CGFloat(Double(worldPos.y) * perspective)

    // Check if on screen
    guard screenX >= 0, screenX < screenWidth, screenY >= 0, screenY < screenHeight else {
        return nil
    }

    return CGPoint(x: screenX, y: screenY)
}

// MARK: - Drawing
private func drawESP() {
    DispatchQueue.main.async {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows
            .filter({ $0.isKeyWindow })
            .first else {
            return
        }

        if espDrawLayer == nil {
            espDrawLayer = CALayer()
            espDrawLayer?.frame = window.bounds
            espDrawLayer?.isOpaque = false
            window.layer.addSublayer(espDrawLayer!)
        }

        espDrawLayer?.sublayers?.forEach { $0.removeFromSuperlayer() }

        for enemy in enemies {
            guard let screenPos = enemy.screenPos, let headPos = enemy.screenHeadPos else {
                continue
            }

            let color = enemy.teamID == myTeamID ? UIColor.green.cgColor : UIColor.red.cgColor

            // Draw head circle
            let headCircle = CAShapeLayer()
            headCircle.path = UIBezierPath(arcCenter: headPos, radius: 15, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true).cgPath
            headCircle.strokeColor = color
            headCircle.fillColor = UIColor.clear.cgColor
            headCircle.lineWidth = 2
            espDrawLayer?.addSublayer(headCircle)

            // Draw body box
            let boxRect = CGRect(x: screenPos.x - 20, y: screenPos.y - 40, width: 40, height: 60)
            let boxLayer = CAShapeLayer()
            boxLayer.path = UIBezierPath(rect: boxRect).cgPath
            boxLayer.strokeColor = color
            boxLayer.fillColor = UIColor.clear.cgColor
            boxLayer.lineWidth = 2
            espDrawLayer?.addSublayer(boxLayer)

            // Draw line from head to body
            let line = CAShapeLayer()
            let linePath = UIBezierPath()
            linePath.move(to: headPos)
            linePath.addLine(to: screenPos)
            line.path = linePath.cgPath
            line.strokeColor = color
            line.lineWidth = 1
            espDrawLayer?.addSublayer(line)

            // Draw HP text
            let hpText = CATextLayer()
            hpText.string = "HP: \(enemy.currentHP)/\(enemy.maxHP)"
            hpText.font = UIFont.systemFont(ofSize: 10)
            hpText.fontSize = 10
            hpText.foregroundColor = color
            hpText.position = CGPoint(x: screenPos.x, y: screenPos.y + 50)
            hpText.alignmentMode = .center
            espDrawLayer?.addSublayer(hpText)
        }

        globallogger.log("[ESP] Drew \(enemies.count) enemies")
    }
}
