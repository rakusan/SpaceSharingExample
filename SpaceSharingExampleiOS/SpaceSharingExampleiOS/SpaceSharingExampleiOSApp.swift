//
//  SpaceSharingExampleiOSApp.swift
//  SpaceSharingExampleiOS
//
//  Created by Yoshikazu Kuramochi on 2024/09/22.
//

import SwiftUI

@main
struct SpaceSharingExampleiOSApp: App {

    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
     }
}
