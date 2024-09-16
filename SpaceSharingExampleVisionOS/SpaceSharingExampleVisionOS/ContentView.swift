//
//  ContentView.swift
//  SpaceSharingExampleVisionOS
//
//  Created by Yoshikazu Kuramochi on 2024/09/14.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {

    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack {
            Button("scan QRs") {
                appModel.startScanningQRs()
            }
            .disabled(appModel.immersiveSpaceState != .open || appModel.isScanningQRs)

            Button("reset") {
                appModel.reset()
            }
            .disabled(appModel.immersiveSpaceState != .open)

            Spacer().frame(height: 50)

            ToggleImmersiveSpaceButton()
        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
