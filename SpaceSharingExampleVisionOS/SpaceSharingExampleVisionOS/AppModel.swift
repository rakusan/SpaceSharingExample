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

    private(set) var isDragging = false
    private(set) var dragStartPosition: SIMD3<Float> = .zero


    func startScanningQRs() {
        isScanningQRs = true
    }

    func reset() {
        isScanningQRs = false
    }

    func qrEntered(name: String, matrix: simd_float4x4, extent: simd_float3) {
        if (scanningQRName == nil) {
            scanningQRName = name
            qrFrameEntity?.isEnabled = true
            qrUpdated(name: name, matrix: matrix, extent: extent)
        }
    }

    func qrUpdated(name: String, matrix: simd_float4x4, extent: simd_float3) {
        if (scanningQRName == name) {
            qrFrameEntity?.setTransformMatrix(matrix, relativeTo: nil)
            qrFrameEntity?.setScale(simd_float3(x: extent.x, y: 0.001, z: extent.z), relativeTo: nil)
        }
    }

    func qrLeaved(name: String) {
        if (scanningQRName == name) {
            scanningQRName = nil
            qrFrameEntity?.isEnabled = false
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
