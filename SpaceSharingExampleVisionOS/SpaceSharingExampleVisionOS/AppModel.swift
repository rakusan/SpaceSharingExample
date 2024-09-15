//
//  AppModel.swift
//  SpaceSharingExampleVisionOS
//
//  Created by Yoshikazu Kuramochi on 2024/09/14.
//

import SwiftUI

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

    private(set) var isDragging = false
    private(set) var dragStartPosition: SIMD3<Float> = .zero

    func startDrag(at position: SIMD3<Float>) {
        isDragging = true
        dragStartPosition = position
    }

    func endDrag() {
        isDragging = false
    }
}
