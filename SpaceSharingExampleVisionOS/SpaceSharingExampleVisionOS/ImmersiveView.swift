//
//  ImmersiveView.swift
//  SpaceSharingExampleVisionOS
//
//  Created by Yoshikazu Kuramochi on 2024/09/14.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {

    @Environment(AppModel.self) private var appModel

    var body: some View {
        RealityView { content in
            // Add the initial RealityKit content
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)

                // Put skybox here.  See example in World project available at
                // https://developer.apple.com/
            }
        }
        .gesture(
            DragGesture().targetedToAnyEntity()
                .onChanged { value in
                    let entity = value.entity

                    if !appModel.isDragging {
                        appModel.startDrag(at: entity.position(relativeTo: nil))
                    }

                    let tr3D = value.convert(value.gestureValue.translation3D, from: .local, to: .scene)
                    let offset = SIMD3<Float>(x: Float(tr3D.x), y: Float(tr3D.y), z: Float(tr3D.z))
                    entity.setPosition(appModel.dragStartPosition + offset, relativeTo: nil)
                }
                .onEnded { value in
                    appModel.endDrag()
                }
        )
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
