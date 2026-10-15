//
//  WallpaperSwapApp.swift
//  WallpaperSwap
//

import SwiftUI

@main
struct WallpaperSwapApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
        }
    }
}
