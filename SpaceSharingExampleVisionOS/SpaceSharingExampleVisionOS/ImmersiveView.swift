//
//  ImmersiveView.swift
//  SpaceSharingExampleVisionOS
//
//  Created by Yoshikazu Kuramochi on 2024/09/14.
//

import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ImmersiveView: View {

    @Environment(AppModel.self) private var appModel

    private let arkitSession = ARKitSession()
    @State private var qrScanningTask: Task<Void, Never>?

    var body: some View {
        RealityView { content in
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
                appModel.immersiveContentEntity = immersiveContentEntity
                if let sphere = immersiveContentEntity.findEntity(named: "Sphere") {
                    appModel.shperePosition = sphere.position(relativeTo: nil)
                }
            }
        }
        .gesture(
            DragGesture().targetedToAnyEntity()
                .onChanged { value in
                    let entity = value.entity
                    if (entity.name == "Sphere") {
                        if !appModel.isDragging {
                            appModel.startDrag(at: entity.position(relativeTo: nil))
                        }
                        let tr3D = value.convert(value.gestureValue.translation3D, from: .local, to: .scene)
                        let offset = SIMD3<Float>(x: Float(tr3D.x), y: Float(tr3D.y), z: Float(tr3D.z))
                        entity.setPosition(appModel.dragStartPosition + offset, relativeTo: nil)
                        appModel.shperePosition = entity.position(relativeTo: nil)
                    }
                }
                .onEnded { value in
                    if (value.entity.name == "Sphere") {
                        appModel.endDrag()
                    }
                }
        )
        .gesture(
            TapGesture().targetedToAnyEntity()
                .onEnded { value in
                    if (value.entity.name == "QR_Frame") {
                        appModel.qrAdd()
                    }
                }
        )
        .onChange(of: appModel.isScanningQRs) {
            if (appModel.isScanningQRs) {
                startQRScanning()
            } else {
                endQRScanning()
            }
        }
    }

    private func startQRScanning() {
        qrScanningTask = Task {
            await arkitSession.queryAuthorization(for: [.worldSensing])
            let barcodeDetection = BarcodeDetectionProvider(symbologies: [.qr])
            do {
                try await arkitSession.run([barcodeDetection])
            } catch {
                return
            }
            for await anchorUpdate in barcodeDetection.anchorUpdates {
                let anchor = anchorUpdate.anchor
                guard let name = anchor.payloadString else { continue }
                switch anchorUpdate.event {
                case .added, .updated:
                    appModel.qrUpdated(name: name, transform: anchor.originFromAnchorTransform, extent: anchor.extent)
                case .removed:
                    appModel.qrLeaved(name: name)
                }
            }
        }
    }

    private func endQRScanning() {
        qrScanningTask?.cancel()
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
