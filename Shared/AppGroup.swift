//
//  AppGroup.swift
//  WallpaperSwap
//

import Foundation

/// Identifiers shared by the app and the widget. The defaults match
/// Config/Identifiers.xcconfig. A free Personal Team install will not
/// actually get a shared container — containerURL() returns nil until the
/// Paid entitlements are signed.
enum AppGroup {
    static let fallbackIdentifier = "group.app.wallpaperswap.shared"
    static let fallbackContainer = "iCloud.app.wallpaperswap.ios"

    static var identifier: String {
        resolved(infoKey: "AppGroupIdentifier", fallback: fallbackIdentifier)
    }

    static var cloudKitContainerID: String {
        resolved(infoKey: "CloudKitContainerIdentifier", fallback: fallbackContainer)
    }

    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    private static func resolved(infoKey: String, fallback: String) -> String {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: infoKey) as? String else {
            return fallback
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.contains("$(") {
            return fallback
        }
        return trimmed
    }
}
