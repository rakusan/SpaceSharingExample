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
            ToggleImmersiveSpaceButton()

            Spacer().frame(height: 50)

            Button("scan QRs") {
                appModel.startScanningQRs()
            }
            .disabled(appModel.immersiveSpaceState != .open || appModel.isScanningQRs || appModel.qrCount >= 2)

            Button("reset") {
                appModel.reset()
            }
            .disabled(appModel.immersiveSpaceState != .open)

            Text(qrCountText)
        }
        .padding()
    }

    private var qrCountText: String {
        if (appModel.immersiveSpaceState != .open) {
            " "
        } else {
            switch appModel.qrCount {
            case 0: "QRコードを2つスキャンしてください"
            case 1: "QRコードをもう1つスキャンしてください"
            default : "QRコードのスキャンが完了しました"
            }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
