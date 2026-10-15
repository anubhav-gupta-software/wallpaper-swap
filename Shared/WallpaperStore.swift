//
//  WallpaperStore.swift
//  WallpaperSwap
//

import Foundation
import UIKit

/// Photos and history for the app, the widget, and the Shortcuts action.
/// Extension-safe: no UIApplication, no networking.
final class WallpaperStore {
    static let shared = WallpaperStore()

    private let queue = DispatchQueue(label: "app.wallpaperswap.store")
    private let folderName = "WallpaperSwap"
    private let manifestName = "manifest.json"
    private let currentImageName = "current.jpg"
    private let currentMetaName = "current.json"

    var usesAppGroup: Bool {
        AppGroup.containerURL() != nil
    }

    func loadManifest(migrate: Bool = false) -> Manifest {
        queue.sync {
            if migrate {
                migrateLegacyLocked()
            }
            return readManifestLocked()
        }
    }

    func save(manifest: Manifest) {
        queue.sync {
            let directory = directoryURLLocked(create: true)
            let url = directory.appendingPathComponent(manifestName)
            guard let data = try? JSONCoding.encode(manifest) else { return }
            try? data.write(to: url, options: .atomic)
            protect(url)
        }
    }

    @discardableResult
    func importJPEG(_ data: Data, id: UUID) throws -> String {
        try queue.sync {
            let directory = directoryURLLocked(create: true)
            let relative = "swaps/\(id.uuidString).jpg"
            let imageURL = directory.appendingPathComponent(relative)
            try FileManager.default.createDirectory(
                at: imageURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: imageURL, options: .atomic)
            protect(imageURL)
            if let thumb = thumbnailJPEG(from: data) {
                let thumbURL = directory.appendingPathComponent("thumbs/\(id.uuidString).jpg")
                try FileManager.default.createDirectory(
                    at: thumbURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try thumb.write(to: thumbURL, options: .atomic)
                protect(thumbURL)
            }
            return relative
        }
    }

    func setCurrent(relativePath: String, caption: String, date: Date, swapID: UUID) throws {
        try queue.sync {
            let directory = directoryURLLocked(create: true)
            let source = directory.appendingPathComponent(relativePath)
            let destination = directory.appendingPathComponent(currentImageName)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            protect(destination)
            let meta = CurrentWallpaper(caption: caption, date: date, swapID: swapID)
            let metaURL = directory.appendingPathComponent(currentMetaName)
            let data = try JSONCoding.encode(meta)
            try data.write(to: metaURL, options: .atomic)
            protect(metaURL)
        }
    }

    func clearCurrent() {
        queue.sync {
            let directory = directoryURLLocked(create: false)
            let files = [currentImageName, currentMetaName].map { directory.appendingPathComponent($0) }
            for url in files where FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    func loadCurrentJPEG() -> Data? {
        queue.sync {
            let url = directoryURLLocked(create: false).appendingPathComponent(currentImageName)
            return try? Data(contentsOf: url)
        }
    }

    func loadCurrentImage() -> UIImage? {
        guard let data = loadCurrentJPEG() else { return nil }
        return UIImage(data: data)
    }

    func loadCurrentMeta() -> CurrentWallpaper? {
        queue.sync {
            let url = directoryURLLocked(create: false).appendingPathComponent(currentMetaName)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONCoding.decode(CurrentWallpaper.self, from: data)
        }
    }

    func image(relativePath: String) -> UIImage? {
        queue.sync {
            let url = directoryURLLocked(create: false).appendingPathComponent(relativePath)
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }
    }

    func thumbnail(for swap: Swap) -> UIImage? {
        queue.sync {
            let directory = directoryURLLocked(create: false)
            let thumb = directory.appendingPathComponent("thumbs/\(swap.id.uuidString).jpg")
            if let data = try? Data(contentsOf: thumb), let image = UIImage(data: data) {
                return image
            }
            let full = directory.appendingPathComponent(swap.imageFile)
            guard let data = try? Data(contentsOf: full) else { return nil }
            return UIImage(data: data)
        }
    }

    func deleteImage(relativePath: String, id: UUID) {
        queue.sync {
            let directory = directoryURLLocked(create: false)
            let urls = [
                directory.appendingPathComponent(relativePath),
                directory.appendingPathComponent("thumbs/\(id.uuidString).jpg")
            ]
            for url in urls where FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func readManifestLocked() -> Manifest {
        let url = directoryURLLocked(create: false).appendingPathComponent(manifestName)
        guard let data = try? Data(contentsOf: url),
              let manifest = try? JSONCoding.decode(Manifest.self, from: data) else {
            return .empty
        }
        return manifest
    }

    private func directoryURLLocked(create: Bool) -> URL {
        let base = AppGroup.containerURL()
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent(folderName, isDirectory: true)
        if create {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    /// When a paid profile shows up later, move photos the free install saved
    /// in the app container into the shared group so the widget can see them.
    private func migrateLegacyLocked() {
        guard let group = AppGroup.containerURL() else { return }
        let destination = group.appendingPathComponent(folderName, isDirectory: true)
        let legacyBase = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let legacy = legacyBase.appendingPathComponent(folderName, isDirectory: true)
        let legacyManifest = legacy.appendingPathComponent(manifestName)
        let groupManifest = destination.appendingPathComponent(manifestName)
        let fm = FileManager.default
        guard fm.fileExists(atPath: legacyManifest.path),
              !fm.fileExists(atPath: groupManifest.path) else {
            return
        }
        try? copyTree(from: legacy, to: destination)
    }

    private func copyTree(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        let items = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: [.isDirectoryKey])
        for item in items {
            let dest = destination.appendingPathComponent(item.lastPathComponent)
            let values = try item.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                try copyTree(from: item, to: dest)
            } else if !fm.fileExists(atPath: dest.path) {
                try fm.copyItem(at: item, to: dest)
            }
        }
    }

    private func thumbnailJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxEdge: CGFloat = 480
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxEdge / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: 0.72)
    }

    private func protect(_ url: URL) {
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }
}
