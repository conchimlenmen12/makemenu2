//
//  TweaksView.swift
//  lara
//
//  Created by lunginspector on 5/3/26.
//

import SwiftUI

struct TweaksView: View {
    @AppStorage("logsdisplaymode") private var selectedlogsdisplaymode: logsdisplaymode = .toolbar
    @ObservedObject var mgr: laramgr

    var body: some View {
        NavigationStack {
            List {
                Section(header: HeaderLabel(text: "Games", icon: "gamecontroller")) {
                    NavigationLink("Free Fire Aimbot", destination: AimbotFFView(mgr: mgr))
                        .disabled(!mgr.dsready)
                    NavigationLink("Free Fire ESP", destination: EspFFView(mgr: mgr))
                        .disabled(!mgr.dsready)
                }
            }
            .disabled(!mgr.dsready)
            .navigationTitle("Tweaks")
            .toolbar {
                if selectedlogsdisplaymode == .toolbar {
                    Button(action: {
                        mgr.showLogs.toggle()
                    }) {
                        Image(systemName: "terminal")
                    }
                }
            }
        }
    }
}
