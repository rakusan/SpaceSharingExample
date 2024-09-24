//
//  AppModel.swift
//  SpaceSharingExampleiOS
//
//  Created by Yoshikazu Kuramochi on 2024/09/22.
//

import SwiftUI
import RealityKit

/// Maintains app-wide state
@MainActor
@Observable
class AppModel {

    var immersiveContentEntity: Entity? {
        didSet {
            qrFrameEntity = immersiveContentEntity?.findEntity(named: "QR_Frame")
            qrFrameEntity?.isEnabled = false
            sphereEntity = immersiveContentEntity?.findEntity(named: "Sphere")
        }
    }
    private var qrFrameEntity: Entity?
    private var sphereEntity: Entity?

    private(set) var isScanningQRs = false
    private var scanningQRName: String?
    private var qrPositions: [NamedPosition] = []
    var qrCount: Int { qrPositions.count }

    init() {
        Task {
            while (true) {
                if (qrCount >= 2) {
                    // This is an example URL, replace it with your valid URL.
                    var request = URLRequest(url: URL(string:"http://www.example.com/?t=\(Date.now.timeIntervalSince1970)")!)
                    request.httpMethod = "GET"
                    request.timeoutInterval = 5
                    do {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        //if let response = response as? HTTPURLResponse {
                        //    print("response.statusCode = \(response.statusCode)")
                        //}
                        let decoder = JSONDecoder()
                        let spaceSharingData = try decoder.decode(SpaceSharingData.self, from: data)
                        updateSpaceSharing(spaceSharingData)
                    } catch let error {
                        print(error.localizedDescription)
                    }
                }
                try await Task.sleep(nanoseconds: 500000000)  // 0.5sec
            }
        }
    }

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

    private func updateSpaceSharing(_ spaceSharingData: SpaceSharingData) {
        if qrCount < 2 { return }

        guard let myQR1 = qrPositions.first else { return }
        guard let myQR2 = qrPositions.last else { return }
        guard let ssQR1 = spaceSharingData.qrPositions.first(where: { $0.name == myQR1.name }) else { return }
        guard let ssQR2 = spaceSharingData.qrPositions.first(where: { $0.name == myQR2.name }) else { return }

        guard let sphereEntity, let parent = sphereEntity.parent else { return }
        sphereEntity.setPosition(spaceSharingData.spherePosition, relativeTo: parent)

        let myQRVec = myQR1.position - myQR2.position
        let ssQRVec = ssQR1.position - ssQR2.position
        let orientation = simd_quatf(from: simd_float3(ssQRVec.x, 0, ssQRVec.z), to: simd_float3(myQRVec.x, 0, myQRVec.z))
        parent.setOrientation(orientation, relativeTo: nil)
        parent.setPosition(myQR1.position - normalize(simd_act(orientation, ssQR1.position)) * length(ssQR1.position), relativeTo: nil)
    }
}

struct NamedPosition: Codable {
    let name: String
    let position: simd_float3
}

struct SpaceSharingData: Codable {
    let qrPositions: [NamedPosition]
    let spherePosition: simd_float3
}
