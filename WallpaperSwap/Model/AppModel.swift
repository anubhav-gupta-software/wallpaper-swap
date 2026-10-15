//
//  AppModel.swift
//  WallpaperSwap
//

import Foundation
import Observation
import Photos
import UIKit
import WidgetKit

@MainActor
@Observable
final class AppModel {
    var name: String
    var syncMode: SyncMode
    var mirrorSends: Bool
    var pairing: Pairing?
    var swaps: [Swap]
    var currentImage: UIImage?
    var currentMeta: CurrentWallpaper?
    var status: String?
    var banner: String?
    var lastError: String?
    var isWorking = false
    var showIntro = false
    var selectedTab: AppTab = .home

    private let store: WallpaperStore
    private let defaults: UserDefaults
    private var transport: any SyncTransport

    private enum Keys {
        static let name = "profile.name"
        static let mode = "sync.mode"
        static let mirror = "sync.mirrorSends"
    }

    init(store: WallpaperStore = .shared, defaults: UserDefaults = .standard, startTransport: Bool = true) {
        self.store = store
        self.defaults = defaults
        name = defaults.string(forKey: Keys.name) ?? ""
        if let raw = defaults.string(forKey: Keys.mode), let mode = SyncMode(rawValue: raw) {
            syncMode = mode
        } else {
            syncMode = .local
        }
        if defaults.object(forKey: Keys.mirror) == nil {
            mirrorSends = true
        } else {
            mirrorSends = defaults.bool(forKey: Keys.mirror)
        }
        let manifest = store.loadManifest(migrate: true)
        pairing = manifest.pairing
        swaps = manifest.swaps.sorted { $0.createdAt > $1.createdAt }
        currentMeta = store.loadCurrentMeta()
        currentImage = store.loadCurrentImage()
        transport = LocalSyncTransport()
        if startTransport {
            revive()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var needsIntro: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || showIntro
    }

    func completeIntro(name raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        updateName(trimmed)
        showIntro = false
        return true
    }

    func updateName(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        name = String(trimmed.prefix(40))
        defaults.set(name, forKey: Keys.name)
    }

    func setMirror(_ on: Bool) {
        mirrorSends = on
        defaults.set(on, forKey: Keys.mirror)
    }

    func setSyncMode(_ mode: SyncMode) {
        guard mode != syncMode else { return }
        if pairing != nil {
            lastError = "Unpair first, then switch how you sync."
            return
        }
        syncMode = mode
        defaults.set(mode.rawValue, forKey: Keys.mode)
        status = nil
        revive()
    }

    func pairLocally(partnerName raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Add your friend's name."
            return
        }
        let friend = String(trimmed.prefix(40))
        syncMode = .local
        defaults.set(syncMode.rawValue, forKey: Keys.mode)
        pairing = Pairing(
            id: UUID(),
            code: InviteCode.make(),
            partnerName: friend,
            isConfirmed: true,
            role: .preview,
            transport: .local,
            createdAt: Date()
        )
        persist()
        revive()
        banner = "Paired with \(friend) on this iPhone."
        Haptics.success()
    }

    func beginHosting() async throws -> String {
        guard syncMode == .nearby || syncMode == .iCloud else {
            throw SyncFailure("Switch to Nearby or iCloud to make a code.")
        }
        isWorking = true
        defer { isWorking = false }
        let code = try await transport.beginHosting(myName: name)
        pairing = Pairing(
            id: UUID(),
            code: code,
            partnerName: "",
            isConfirmed: false,
            role: .host,
            transport: syncMode,
            createdAt: Date()
        )
        persist()
        return code
    }

    func join(code raw: String) async throws {
        isWorking = true
        defer { isWorking = false }
        let pairing = try await transport.join(code: InviteCode.normalize(raw), myName: name)
        self.pairing = pairing
        persist()
        banner = "Paired with \(pairing.displayName)."
        Haptics.success()
    }

    func unpair() {
        transport.stop()
        pairing = nil
        status = nil
        persist()
        revive()
        banner = "Unpaired. Your photos stay in History."
    }

    func send(_ image: UIImage) async {
        guard !isWorking else { return }
        guard let pairing else {
            lastError = "Pair with a friend first."
            return
        }
        guard pairing.isConfirmed else {
            lastError = "Waiting for your friend to join before you can send."
            return
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.86) else {
            lastError = "Couldn't prepare that photo."
            return
        }
        isWorking = true
        lastError = nil
        defer { isWorking = false }
        let id = UUID()
        do {
            if pairing.transport != .local {
                try await transport.send(jpeg: jpeg, id: id, myName: name, pairing: pairing)
            }
            let file = try store.importJPEG(jpeg, id: id)
            let mirrored = pairing.transport == .local && mirrorSends
            let swap = Swap(
                id: id,
                direction: .sent,
                createdAt: Date(),
                personName: pairing.displayName,
                imageFile: file,
                mirroredToMyScreen: mirrored
            )
            swaps.insert(swap, at: 0)
            if mirrored {
                try store.setCurrent(
                    relativePath: file,
                    caption: "Sent to \(pairing.displayName)",
                    date: swap.createdAt,
                    swapID: id
                )
                reloadCurrent()
                WidgetCenter.shared.reloadAllTimelines()
            }
            trim()
            persist()
            banner = mirrored
                ? "On your screen, and marked as sent to \(pairing.displayName)."
                : "Sent to \(pairing.displayName)."
            Haptics.success()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func useSample() {
        let image = SampleWallpaper.render()
        guard let jpeg = image.jpegData(compressionQuality: 0.9) else {
            lastError = "Couldn't make a sample photo."
            return
        }
        let id = UUID()
        do {
            let file = try store.importJPEG(jpeg, id: id)
            let swap = Swap(
                id: id,
                direction: .received,
                createdAt: Date(),
                personName: "Sample",
                imageFile: file,
                mirroredToMyScreen: false
            )
            swaps.insert(swap, at: 0)
            try store.setCurrent(relativePath: file, caption: "Sample", date: swap.createdAt, swapID: id)
            reloadCurrent()
            trim()
            persist()
            WidgetCenter.shared.reloadAllTimelines()
            banner = "Sample photo is ready. You can point a Shortcut at it."
            Haptics.success()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func useOnMyScreen(_ swap: Swap) {
        do {
            try store.setCurrent(
                relativePath: swap.imageFile,
                caption: caption(for: swap),
                date: swap.createdAt,
                swapID: swap.id
            )
            reloadCurrent()
            WidgetCenter.shared.reloadAllTimelines()
            banner = "That's the photo on your screen now."
            Haptics.success()
        } catch {
            lastError = "Couldn't use that photo."
        }
    }

    func delete(_ swap: Swap) {
        swaps.removeAll { $0.id == swap.id }
        store.deleteImage(relativePath: swap.imageFile, id: swap.id)
        if currentMeta?.swapID == swap.id {
            if let next = swaps.first {
                try? store.setCurrent(
                    relativePath: next.imageFile,
                    caption: caption(for: next),
                    date: next.createdAt,
                    swapID: next.id
                )
            } else {
                store.clearCurrent()
            }
            reloadCurrent()
            WidgetCenter.shared.reloadAllTimelines()
        }
        persist()
    }

    func saveToPhotos(_ image: UIImage) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            banner = "Saved to Photos."
        } catch {
            lastError = "Couldn't save to Photos."
        }
    }

    func refresh(reportErrors: Bool = false) async {
        guard let pairing, pairing.transport != .local else { return }
        do {
            let result = try await transport.refresh(pairing: pairing, myName: name)
            if let updated = result.pairing {
                self.pairing = updated
                persist()
                if updated.isConfirmed {
                    banner = "\(updated.displayName) joined."
                }
            }
            for photo in result.photos {
                accept(photo)
            }
            if result.photos.isEmpty, reportErrors {
                status = "No new photos."
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            if reportErrors {
                lastError = message
            } else {
                status = message
            }
        }
    }

    func caption(for swap: Swap) -> String {
        switch swap.direction {
        case .received: swap.personName
        case .sent: "Sent to \(swap.personName)"
        }
    }

    private func accept(_ photo: IncomingPhoto) {
        guard !swaps.contains(where: { $0.id == photo.id }) else { return }
        do {
            let file = try store.importJPEG(photo.jpeg, id: photo.id)
            let swap = Swap(
                id: photo.id,
                direction: .received,
                createdAt: photo.sentAt,
                personName: photo.senderName,
                imageFile: file,
                mirroredToMyScreen: false
            )
            swaps.insert(swap, at: 0)
            swaps.sort { $0.createdAt > $1.createdAt }
            try store.setCurrent(
                relativePath: file,
                caption: photo.senderName,
                date: photo.sentAt,
                swapID: photo.id
            )
            reloadCurrent()
            if var pairing {
                if pairing.partnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    pairing.partnerName = photo.senderName
                }
                pairing.isConfirmed = true
                self.pairing = pairing
            }
            trim()
            persist()
            WidgetCenter.shared.reloadAllTimelines()
            banner = "New photo from \(photo.senderName)."
            Haptics.success()
        } catch {
            lastError = "A photo arrived, but it couldn't be saved."
        }
    }

    private func handle(_ event: SyncEvent) {
        switch event {
        case .status(let text):
            status = text
        case .failed(let text):
            lastError = text
            status = text
        case .paired(let incoming):
            let changed = pairing?.partnerName != incoming.partnerName || pairing?.isConfirmed != incoming.isConfirmed || pairing?.code != incoming.code
            pairing = incoming
            persist()
            if changed, incoming.isConfirmed {
                banner = "Paired with \(incoming.displayName)."
                Haptics.success()
            }
        case .received(let photo):
            accept(photo)
        }
    }

    private func revive() {
        transport.stop()
        switch syncMode {
        case .local:
            transport = LocalSyncTransport()
        case .nearby:
            transport = NearbySyncTransport()
        case .iCloud:
            transport = CloudKitSyncTransport()
        }
        transport.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handle(event)
            }
        }
        if let pairing {
            transport.restore(pairing: pairing, myName: name)
        }
    }

    private func reloadCurrent() {
        currentMeta = store.loadCurrentMeta()
        currentImage = store.loadCurrentImage()
    }

    private func persist() {
        store.save(manifest: Manifest(pairing: pairing, swaps: swaps))
    }

    private func trim() {
        let limit = 80
        guard swaps.count > limit else { return }
        let currentID = currentMeta?.swapID
        var kept: [Swap] = []
        var dropped: [Swap] = []
        for swap in swaps {
            if kept.count < limit || swap.id == currentID {
                kept.append(swap)
            } else {
                dropped.append(swap)
            }
        }
        swaps = kept
        for swap in dropped {
            store.deleteImage(relativePath: swap.imageFile, id: swap.id)
        }
    }
}

enum AppTab: Hashable {
    case home
    case history
    case guide
}
