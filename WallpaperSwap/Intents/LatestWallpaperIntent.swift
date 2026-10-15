//
//  LatestWallpaperIntent.swift
//  WallpaperSwap
//

import AppIntents
import UniformTypeIdentifiers

struct LatestWallpaperIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Latest Wallpaper"
    static var description = IntentDescription("Returns the newest photo your friend sent, ready for the Set Wallpaper action.")
    static var openAppWhenRun = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        guard let data = WallpaperStore.shared.loadCurrentJPEG() else {
            throw WallpaperIntentError.noPhoto
        }
        let file = IntentFile(data: data, filename: "Wallpaper.jpg", type: .jpeg)
        return .result(value: file)
    }
}

struct WallpaperIntentError: Error, CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource

    static let noPhoto = WallpaperIntentError(
        localizedStringResource: "You haven't received a photo yet. Open Wallpaper Swap and try a sample, or wait for your friend."
    )
}

struct WallpaperSwapShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .orange

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LatestWallpaperIntent(),
            phrases: [
                "Get my latest \(.applicationName)",
                "Get the latest wallpaper from \(.applicationName)"
            ],
            shortTitle: "Latest Wallpaper",
            systemImageName: "photo.fill"
        )
    }
}
