//
//  LocalSyncTransport.swift
//  WallpaperSwap
//

import Foundation

/// On-device stand-in. Pairing and mirroring are handled by AppModel so
/// someone can try the crop, the history, and the Shortcut with no second
/// phone and no account.
final class LocalSyncTransport: SyncTransport {
    var onEvent: ((SyncEvent) -> Void)?

    func restore(pairing: Pairing, myName: String) {}

    func beginHosting(myName: String) async throws -> String {
        throw SyncFailure("On-device pairing doesn't use an invite code. Enter your friend's name instead.")
    }

    func join(code: String, myName: String) async throws -> Pairing {
        throw SyncFailure("On-device pairing doesn't use an invite code. Enter your friend's name instead.")
    }

    func send(jpeg: Data, id: UUID, myName: String, pairing: Pairing) async throws {}

    func refresh(pairing: Pairing, myName: String) async throws -> RefreshResult {
        RefreshResult()
    }

    func stop() {}
}
