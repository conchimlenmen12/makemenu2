import SwiftUI

struct AimbotFFView: View {
    @ObservedObject var mgr: laramgr
    @AppStorage("aimbotFF_enabled") private var aimbotEnabled = false
    @AppStorage("aimbotFF_speed") private var aimSpeedInt = 50
    @State private var log: String = ""

    private var aimSpeed: Float {
        get { Float(aimSpeedInt) }
        set { aimSpeedInt = Int(newValue) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section(header: HeaderLabel(text: "Aimbot Status", icon: "crosshair")) {
                    HStack {
                        Text("Darksword Status")
                        Spacer()
                        if mgr.dsready {
                            Text("Ready")
                                .foregroundColor(.green)
                        } else {
                            Text("Not Ready")
                                .foregroundColor(.red)
                        }
                    }

                    HStack {
                        Text("Aimbot State")
                        Spacer()
                        if isAimbotEnabled() {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Inactive", systemImage: "circle")
                                .foregroundColor(.gray)
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { isAimbotEnabled() },
                        set: { newValue in
                            setAimbotEnabled(newValue)
                        }
                    )) {
                        HStack {
                            Image(systemName: "target")
                            Text("Enable Aimbot")
                        }
                    }
                    .disabled(!mgr.dsready)
                }

                Section(header: HeaderLabel(text: "Settings", icon: "slider.horizontal.3")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Aim Speed")
                            Spacer()
                            Text("\(Int(aimSpeed))%")
                                .foregroundColor(.blue)
                        }
                        Slider(value: $aimSpeed, in: 0...100, step: 1)
                            .disabled(!mgr.dsready)
                    }
                    .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Speed Controls")
                            .font(.caption)
                            .foregroundColor(.gray)

                        HStack(spacing: 8) {
                            Button("Smooth") {
                                aimSpeed = 50
                            }
                            .font(.caption)
                            .disabled(!mgr.dsready)

                            Button("Fast") {
                                aimSpeed = 80
                            }
                            .font(.caption)
                            .disabled(!mgr.dsready)

                            Button("Instant") {
                                aimSpeed = 100
                            }
                            .font(.caption)
                            .disabled(!mgr.dsready)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: HeaderLabel(text: "Testing", icon: "wrench.adjustable")) {
                    Button(action: {
                        testAimbotFF()
                        updateTestLog()
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Test Aimbot")
                            Spacer()
                            if mgr.dsready {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .disabled(!mgr.dsready)
                }

                Section(header: HeaderLabel(text: "Debug Log", icon: "terminal")) {
                    ScrollView {
                        Text(log.isEmpty ? "(no activity)" : log)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .navigationTitle("Free Fire Aimbot")
        }
    }

    private func updateTestLog() {
        log = "[Aimbot] Test Status:\n"

        if !mgr.dsready {
            log += "[Aimbot] ERROR: Darksword not ready\n"
            return
        }

        log += "[Aimbot] ✓ Darksword is ready\n"
        log += "[Aimbot] ✓ Kernel access available\n"
        log += "[Aimbot] Status: \(isAimbotEnabled() ? "ENABLED" : "DISABLED")\n"
        log += "[Aimbot] Speed: \(Int(getAimbotSpeed()))%\n"
        log += "[Aimbot] \n"
        log += "Ready to integrate with game loop:\n"
        log += "  - isAimbotEnabled() → Bool\n"
        log += "  - getAimbotSpeed() → Float\n"
        log += "  - applyAimbot(...)\n"
    }
}

#Preview {
    AimbotFFView(mgr: laramgr.shared)
}
