import SwiftUI

struct SpeedFFView: View {
    @ObservedObject var mgr: laramgr
    @ObservedObject var gameDetector = GameDetector.shared
    @State private var speedEnabled = false
    @State private var speedValue: Float = 0.16

    var body: some View {
        NavigationStack {
            List {
                Section(header: HeaderLabel(text: "Game Detection", icon: "gamecontroller")) {
                    HStack {
                        Text("Game Status")
                        Spacer()
                        Text(gameDetector.gameStatus)
                            .foregroundColor(gameDetector.isInMatch ? .green : .orange)
                            .font(.caption)
                    }

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
                }

                Section(header: HeaderLabel(text: "Speed Status", icon: "speedometer")) {

                    Toggle(isOn: $speedEnabled) {
                        HStack {
                            Image(systemName: "hare.fill")
                            Text("Enable Speed x\(String(format: "%.2f", speedValue))")
                        }
                    }
                    .disabled(!mgr.dsready)
                    .onChange(of: speedEnabled) { newValue in
                        setSpeedEnabled(newValue)
                        if newValue {
                            GameLoopManager.shared.start()
                        } else {
                            GameLoopManager.shared.stop()
                        }
                    }
                }

                Section(header: HeaderLabel(text: "Speed Control", icon: "slider.horizontal.3")) {
                    HStack {
                        Text("Speed")
                        Slider(value: $speedValue, in: 0.1...1.0, step: 0.05)
                            .onChange(of: speedValue) { newValue in
                                setSpeedValue(newValue)
                            }
                        Text("\(String(format: "%.2f", speedValue))x")
                            .frame(width: 50)
                    }

                    HStack {
                        Button(action: { speedValue = 0.16 }) {
                            Label("x0.16", systemImage: "tortoise.fill")
                        }
                        .frame(maxWidth: .infinity)

                        Button(action: { speedValue = 0.5 }) {
                            Label("x0.5", systemImage: "figure.walk")
                        }
                        .frame(maxWidth: .infinity)

                        Button(action: { speedValue = 1.0 }) {
                            Label("x1.0", systemImage: "figure.stairs")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                Section(header: HeaderLabel(text: "Info", icon: "info.circle")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("x0.16 = Very Slow (1/6 speed)")
                            .font(.caption)
                        Text("x0.5 = Half Speed")
                            .font(.caption)
                        Text("x1.0 = Normal Speed")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Free Fire Speed")
        }
        .onAppear {
            speedEnabled = isSpeedEnabled()
            speedValue = getSpeedValue()
            gameDetector.startDetection()
        }
        .onDisappear {
            gameDetector.stopDetection()
        }
    }
}

#Preview {
    SpeedFFView(mgr: laramgr.shared)
}
