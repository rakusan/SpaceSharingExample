//
//  AppModel.swift
//  SpaceSharingExampleVisionOS
//
//  Created by Yoshikazu Kuramochi on 2024/09/14.
//

import SwiftUI
import RealityKit

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {
    let immersiveSpaceID = "ImmersiveSpace"
    enum ImmersiveSpaceState {
        case closed
        case inTransition
        case open
    }
    var immersiveSpaceState = ImmersiveSpaceState.closed

    var immersiveContentEntity: Entity? {
        didSet {
            qrFrameEntity = immersiveContentEntity?.findEntity(named: "QR_Frame")
            qrFrameEntity?.isEnabled = false
        }
    }
    var qrFrameEntity: Entity?

    private(set) var isScanningQRs = false
    private var scanningQRName: String?
    private var qrPositions: [(name: String, position: simd_float3)] = []
    var qrCount: Int { qrPositions.count }

    private(set) var isDragging = false
    private(set) var dragStartPosition: SIMD3<Float> = .zero


    func startScanningQRs() {
        isScanningQRs = true
    }

    func reset() {
        qrRemoveAll()
        isScanningQRs = false
    }

    func qrUpdated(name: String, transform: simd_float4x4, extent: simd_float3) {
        if (scanningQRName == nil && qrPositions.first(where: { (n, _) in n == name }) == nil) {
            scanningQRName = name
            qrFrameEntity?.isEnabled = true
        }
        if (scanningQRName == name) {
            qrFrameEntity?.setTransformMatrix(transform, relativeTo: nil)
            qrFrameEntity?.setScale(simd_float3(x: extent.x, y: 0.001, z: extent.z), relativeTo: nil)
        }
    }

    func qrLeaved(name: String) {
        if (scanningQRName == name) {
            scanningQRName = nil
            qrFrameEntity?.isEnabled = false
        }
    }

    func qrAdd() {
        if let name = scanningQRName, let transform = qrFrameEntity?.transformMatrix(relativeTo: nil) {
            let c3 = transform.columns.3
            qrPositions.append((name, simd_float3(c3.x, c3.y, c3.z)))
            if let clone = qrFrameEntity?.clone(recursive: false) {
                clone.name = name
                if var model = (qrFrameEntity as? ModelEntity)?.model {
                    if var material = model.materials.first as? PhysicallyBasedMaterial {
                        material.baseColor.tint = .green.withAlphaComponent(0.5)
                        material.emissiveColor = PhysicallyBasedMaterial.EmissiveColor(color: .green)
                        model.materials = [material]
                    }
                    (clone as? ModelEntity)?.model = model
                }
                qrFrameEntity?.parent?.addChild(clone)
            }

            qrLeaved(name: name)

            if (qrCount >= 2) {
                isScanningQRs = false
            }
        }
    }

    private func qrRemoveAll() {
        while (!qrPositions.isEmpty) {
            let (name, _) = qrPositions.removeLast()
            qrFrameEntity?.parent?.findEntity(named: name)?.removeFromParent()
        }
    }

    func startDrag(at position: SIMD3<Float>) {
        isDragging = true
        dragStartPosition = position
    }

    func endDrag() {
        isDragging = false
    }
}
