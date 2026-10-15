//
//  SyncTransport.swift
//  WallpaperSwap
//

import Foundation

struct IncomingPhoto: Equatable {
    var id: UUID
    var senderName: String
    var sentAt: Date
    var jpeg: Data
}

enum SyncEvent {
    case status(String)
    case paired(Pairing)
    case received(IncomingPhoto)
    case failed(String)
}

struct SyncFailure: Error, LocalizedError {
    var message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

struct RefreshResult {
    var photos: [IncomingPhoto] = []
    var pairing: Pairing?
}

protocol SyncTransport: AnyObject {
    func restore(pairing: Pairing, myName: String)
    func beginHosting(myName: String) async throws -> String
    func join(code: String, myName: String) async throws -> Pairing
    func send(jpeg: Data, id: UUID, myName: String, pairing: Pairing) async throws
    func refresh(pairing: Pairing, myName: String) async throws -> RefreshResult
    func stop()
    var onEvent: ((SyncEvent) -> Void)? { get set }
}
