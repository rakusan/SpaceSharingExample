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

    private(set) var isScanningQRs = false {
        didSet {
            sendSpaceSharingData(force: true)
        }
    }

    private var scanningQRName: String?
    private var qrPositions: [NamedPosition] = []
    var qrCount: Int { qrPositions.count }

    private(set) var isDragging = false
    private(set) var dragStartPosition = SIMD3<Float>.zero

    private(set) var isScaling = false
    private(set) var startScale = SIMD3<Float>.one

    private(set) var isRotating = false
    private(set) var rotateStartOrientation = Rotation3D.identity

    var sphereTransform: simd_float4x4 = matrix_identity_float4x4 {
        didSet {
            sendSpaceSharingData(force: false)
        }
    }

    private var sendingTask: URLSessionDataTask?

    func startScanningQRs() {
        isScanningQRs = true
    }

    func reset() {
        qrRemoveAll()
        isScanningQRs = false
    }

    func qrUpdated(name: String, transform: simd_float4x4, extent: simd_float3) {
        if (scanningQRName == nil && qrPositions.first(where: { np in np.name == name }) == nil) {
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
            qrPositions.append(NamedPosition(name: name, position: simd_float3(c3.x, c3.y, c3.z)))
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
            let np = qrPositions.removeLast()
            qrFrameEntity?.parent?.findEntity(named: np.name)?.removeFromParent()
        }
    }

    func startDrag(at position: SIMD3<Float>) {
        isDragging = true
        dragStartPosition = position
    }

    func endDrag() {
        isDragging = false
        sendSpaceSharingData(force: true)
    }

    func startScale(from scale: SIMD3<Float>) {
        isScaling = true
        startScale = scale
    }

    func endScale() {
        isScaling = false
        sendSpaceSharingData(force: true)
    }

    func startRotate(from orientation: simd_quatf) {
        isRotating = true
        rotateStartOrientation = .init(orientation)
    }

    func endRotate() {
        isRotating = false
        sendSpaceSharingData(force: true)
    }

    private func sendSpaceSharingData(force: Bool) {
        if (isScanningQRs || qrCount < 2) {
            return
        }

        if (sendingTask?.state == .running && !force) {
            return
        }
        sendingTask?.cancel()
        sendingTask = nil

        let spaceSharingData = SpaceSharingData(
            qrPositions: qrPositions,
            sphereTransform: sphereTransform
        )

        // This is an example URL, replace it with your valid URL.
        var request = URLRequest(url: URL(string:"http://www.example.com/")!)
        request.httpMethod = "PUT"

        let encoder = JSONEncoder()
        request.httpBody = try! encoder.encode(spaceSharingData)

        sendingTask = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error{
                print(error.localizedDescription)
                return
            }
            if let response = response as? HTTPURLResponse {
                print("response.statusCode = \(response.statusCode)")
            }
            Task {
                try await Task.sleep(nanoseconds: 500000000)  // 0.5sec
            }
        }
        sendingTask?.resume()
    }
}

struct NamedPosition: Codable {
    let name: String
    let position: simd_float3
}

struct SpaceSharingData: Codable {
    let qrPositions: [NamedPosition]
    let sphereTransformColumns: [simd_float4]

    init(qrPositions: [NamedPosition], sphereTransform m: simd_float4x4) {
        self.qrPositions = qrPositions
        self.sphereTransformColumns = [m.columns.0, m.columns.1, m.columns.2, m.columns.3]
    }
}
