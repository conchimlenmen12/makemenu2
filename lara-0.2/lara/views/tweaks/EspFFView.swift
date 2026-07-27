import SwiftUI

struct EspFFView: View {
    @ObservedObject var mgr: laramgr
    @AppStorage("espFF_enabled") private var espEnabled = false
    @State private var log: String = ""

    var body: some View {
        content
            .onAppear {
                if isEspEnabled() {
                    ESPManager.shared.startESPLoop()
                }
            }
            .onDisappear {
                ESPManager.shared.stopESPLoop()
            }
    }

    @ViewBuilder
    private var content: some View {
        NavigationStack {
            List {
                Section(header: HeaderLabel(text: "ESP Status", icon: "eye")) {
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
                        Text("ESP State")
                        Spacer()
                        if isEspEnabled() {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Inactive", systemImage: "circle")
                                .foregroundColor(.gray)
                        }
                    }

                    Toggle(isOn: Binding(
                        get: { isEspEnabled() },
                        set: { newValue in
                            handleESPToggle(newValue)
                        }
                    )) {
                        HStack {
                            Image(systemName: "eye.fill")
                            Text("Enable ESP")
                        }
                    }
                    .disabled(!mgr.dsready)
                }

                Section(header: HeaderLabel(text: "Features", icon: "checkmark.circle")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Enemy detection", systemImage: "person.2.fill")
                            .font(.caption)
                        Label("Head & body boxes", systemImage: "square.fill")
                            .font(.caption)
                        Label("HP display", systemImage: "heart.fill")
                            .font(.caption)
                        Label("Distance lines", systemImage: "line.diagonal")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .padding(.vertical, 4)
                }

                Section(header: HeaderLabel(text: "Testing", icon: "wrench.adjustable")) {
                    Button(action: testESP) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Test ESP Detection")
                            Spacer()
                            if log.contains("enemies") {
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
            .navigationTitle("Free Fire ESP")
        }
    }

    private func handleESPToggle(_ enabled: Bool) {
        setEspEnabled(enabled)
        if enabled {
            ESPManager.shared.startESPLoop()
        } else {
            ESPManager.shared.stopESPLoop()
        }
    }

    private func testESP() {
        log = "[ESP] Starting test...\n"

        if !mgr.dsready {
            log += "[ESP] ERROR: Darksword not ready\n"
            return
        }

        if !initializeESP() {
            log += "[ESP] Initialization failed\n"
            return
        }

        log += "[ESP] ✓ Darksword is ready\n"
        log += "[ESP] ✓ Memory access available\n"
        log += "[ESP] Status: \(isEspEnabled() ? "ENABLED" : "DISABLED")\n"
        log += "[ESP] \n"
        log += "Detecting enemies...\n"

        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
            updateESP()
            DispatchQueue.main.async {
                log += "[ESP] Detection complete\n"
                log += "[ESP] Ready to display on screen\n"
                mgr.logmsg("[EspFF] Test completed")
            }
        }
    }
}

#Preview {
    EspFFView(mgr: laramgr.shared)
}
