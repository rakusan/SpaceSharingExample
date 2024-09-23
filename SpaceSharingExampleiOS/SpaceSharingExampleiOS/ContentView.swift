//
//  ContentView.swift
//  SpaceSharingExampleiOS
//
//  Created by Yoshikazu Kuramochi on 2024/09/21.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ContentView : View {

    @Environment(AppModel.self) private var appModel
    @State private var isPanelHidden = false

    private let spatialTrackingSessionConfiguration = SpatialTrackingSession.Configuration(
        tracking: [],
        sceneUnderstanding: [],
        camera: .back
    )
    private let spatialTrackingSession = SpatialTrackingSession()
    private let arSession = ARSession()
    private let arConfiguration = ARWorldTrackingConfiguration()
    private let qrScanner = QRScanner()

    var body: some View {
        ZStack(alignment: .trailing) {
            RealityView { content in
                arConfiguration.planeDetection = [.horizontal]
                arConfiguration.frameSemantics = [.personSegmentation]
                qrScanner.appModel = appModel
                arSession.delegate = qrScanner
                arSession.run(arConfiguration)

                await spatialTrackingSession.run(
                    spatialTrackingSessionConfiguration,
                    session: arSession,
                    arConfiguration: arConfiguration
                )

                if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                    content.add(immersiveContentEntity)
                    appModel.immersiveContentEntity = immersiveContentEntity
                }

                content.camera = .spatialTracking
            }
            .edgesIgnoringSafeArea(.all)
            .gesture(
                TapGesture().targetedToAnyEntity()
                    .onEnded { value in
                        if (value.entity.name == "QR_Frame") {
                            appModel.qrAdd()
                        }
                    }
            )

            VStack(alignment: .center) {
                Button("scan QRs") {
                    appModel.startScanningQRs()
                }
                .padding()
                .buttonStyle(.borderedProminent)
                .disabled(appModel.isScanningQRs || appModel.qrCount >= 2)

                Button("reset") {
                    appModel.reset()
                }
                .padding()
                .buttonStyle(.borderedProminent)

                Text(qrCountText)
                    .padding([.top, .bottom])
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(minWidth: 200, maxHeight: .infinity)
            .background(Color.black.opacity(0.5))
            .opacity(isPanelHidden ? 0 : 1)
        }
        .edgesIgnoringSafeArea(.trailing)
        .gesture(
            DragGesture()
                .onEnded { value in
                    let h = value.translation.width
                    let v = value.translation.height
                    if abs(h) > abs(v) {
                        if h > 5 {
                            isPanelHidden = true
                        } else if h < 5 {
                            isPanelHidden = false
                        }
                    }
                }
        )
    }

    private var qrCountText: String {
        switch appModel.qrCount {
        case 0: "QRコードを2つ\nスキャンしてください"
        case 1: "QRコードをもう1つ\nスキャンしてください"
        default : "QRコードのスキャンが\n完了しました"
        }
    }
}

#Preview {
    ContentView()
}

class QRScanner : NSObject, ARSessionDelegate {

    var appModel: AppModel?
    private var scanningQRNames: Set<String> = []
    private var taskRunning = false

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if taskRunning { return }
        taskRunning = true

        Task {
            defer { taskRunning = false }
            guard let appModel else { return }

            let oldNames = scanningQRNames
            scanningQRNames = []

            if await appModel.isScanningQRs {
                let ciimg = CIImage(cvImageBuffer: frame.capturedImage)
                let iw = ciimg.extent.size.width
                let ih = ciimg.extent.size.height

                if let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil) {
                    for feature in detector.features(in: ciimg) {
                        if let qrFeature = feature as? CIQRCodeFeature, let name = qrFeature.messageString {
                            scanningQRNames.insert(name)
                            let topLeft = raycast(point: qrFeature.topLeft, iw: iw, ih: ih, session: session, frame: frame)
                            let topRight = raycast(point: qrFeature.topRight, iw: iw, ih: ih, session: session, frame: frame)
                            let bottomLeft = raycast(point: qrFeature.bottomLeft, iw: iw, ih: ih, session: session, frame: frame)
                            let bottomRight = raycast(point: qrFeature.bottomRight, iw: iw, ih: ih, session: session, frame: frame)
                            let matrix = transformMatrix(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
                            let extent = simd_float3(length(topLeft - topRight), 0, length(topLeft - bottomLeft))
                            await appModel.qrUpdated(name: name, transform: matrix, extent: extent)
                        }
                    }
                }
            }

            for name in oldNames.subtracting(scanningQRNames) {
                await appModel.qrLeaved(name: name)
            }
        }
    }

    private func raycast(point: CGPoint, iw: Double, ih: Double, session: ARSession, frame: ARFrame) -> simd_float3 {
        let x = point.x / iw
        let y = (ih - point.y) / ih

        let query = frame.raycastQuery(from: CGPoint(x: x, y: y), allowing: .existingPlaneGeometry, alignment: .horizontal)
        if let result = session.raycast(query).first {
            let c3 = result.worldTransform.columns.3
            return simd_float3(c3.x, c3.y, c3.z)
        }
        return .zero
    }

    private func transformMatrix(
        topLeft: simd_float3,
        topRight: simd_float3,
        bottomLeft: simd_float3,
        bottomRight: simd_float3
    ) -> simd_float4x4 {
        var matrix = simd_float4x4(simd_quatf(from: simd_float3(1, 0, 0), to: normalize(topLeft - topRight)))
        let center = (topLeft + topRight + bottomLeft + bottomRight) / 4
        matrix.columns.3.x = center.x
        matrix.columns.3.y = center.y
        matrix.columns.3.z = center.z
        return matrix
    }
}
