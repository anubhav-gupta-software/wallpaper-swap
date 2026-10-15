//
//  NearbySyncTransport.swift
//  WallpaperSwap
//

import Foundation
import MultipeerConnectivity

/// Invite-code pairing over the local network. No server and no paid
/// capability. Both phones need the app in the foreground; Multipeer
/// doesn't deliver in the background.
final class NearbySyncTransport: NSObject, SyncTransport {
    static let serviceType = "wpswap"

    var onEvent: ((SyncEvent) -> Void)?

    private var myName = "Friend"
    private var activeCode = ""
    private var seekingCode = ""
    private var partnerName = ""
    private var role: PairRole = .host
    private var peerID: MCPeerID?
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var joinContinuation: CheckedContinuation<Pairing, Error>?
    private var joinTimeout: DispatchWorkItem?
    private var partials: [UUID: PartialPhoto] = [:]

    private struct PartialPhoto {
        var jpeg: Data?
        var name: String?
        var sentAt: Date?
    }

    private struct WireMessage: Codable {
        var kind: String
        var name: String?
        var code: String?
        var id: UUID?
        var sentAt: Date?
    }

    func restore(pairing: Pairing, myName: String) {
        DispatchQueue.main.async {
            self.myName = Self.clean(myName)
            self.activeCode = InviteCode.normalize(pairing.code)
            self.partnerName = pairing.partnerName
            self.role = pairing.role
            self.advertiser?.stopAdvertisingPeer()
            self.advertiser = nil
            self.browser?.stopBrowsingForPeers()
            self.browser = nil
            self.session?.disconnect()
            self.prepareSession()
            if pairing.role == .guest {
                self.seekingCode = self.activeCode
                self.startBrowsing()
                self.emit(.status("Looking for \(pairing.displayName) nearby…"))
            } else if pairing.role == .host {
                self.startAdvertising()
                let who = pairing.isConfirmed ? pairing.displayName : "your friend"
                self.emit(.status("Waiting for \(who) to open Wallpaper Swap."))
            }
        }
    }

    func beginHosting(myName: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.main.async {
            self.resumeJoin(.failure(SyncFailure("Stopped looking.")))
            self.stopLocked()
            self.myName = Self.clean(myName)
                self.activeCode = InviteCode.make()
                self.role = .host
                self.partnerName = ""
                self.prepareSession()
                self.startAdvertising()
                self.emit(.status("Share this code. Keep Wallpaper Swap open."))
                continuation.resume(returning: self.activeCode)
            }
        }
    }

    func join(code: String, myName: String) async throws -> Pairing {
        let normalized = InviteCode.normalize(code)
        guard normalized.count == InviteCode.length else {
            throw SyncFailure("Enter the 6-character code.")
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                self.resumeJoin(.failure(SyncFailure("Started another search.")))
                self.stopLocked()
                self.myName = Self.clean(myName)
                self.seekingCode = normalized
                self.activeCode = normalized
                self.role = .guest
                self.prepareSession()
                self.joinContinuation = continuation
                self.startBrowsing()
                self.emit(.status("Looking for \(InviteCode.grouped(normalized)) nearby…"))
                let timeout = DispatchWorkItem { [weak self] in
                    self?.resumeJoin(.failure(SyncFailure("Couldn't find that code nearby. Keep both apps open, on the same Wi-Fi, and try again.")))
                    self?.stopBrowsing()
                }
                self.joinTimeout = timeout
                DispatchQueue.main.asyncAfter(deadline: .now() + 40, execute: timeout)
            }
        }
    }

    func send(jpeg: Data, id: UUID, myName: String, pairing: Pairing) async throws {
        guard jpeg.count < 15_000_000 else {
            throw SyncFailure("That photo is too large to send nearby.")
        }
        let snapshot: (session: MCSession, peer: MCPeerID)? = await MainActor.run {
            guard let session = self.session, let peer = session.connectedPeers.first else { return nil }
            return (session, peer)
        }
        guard let snapshot else {
            throw SyncFailure("\(pairing.displayName) isn't connected. Keep both apps open and try again.")
        }
        let session = snapshot.session
        let peer = snapshot.peer
        let message = WireMessage(kind: "photo", name: Self.clean(myName), code: pairing.code, id: id, sentAt: Date())
        let meta = try JSONCoding.encode(message)
        try session.send(meta, toPeers: [peer], with: .reliable)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(id.uuidString).jpg")
        try jpeg.write(to: url, options: .atomic)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            session.sendResource(at: url, withName: "\(id.uuidString).jpg", toPeer: peer) { error in
                try? FileManager.default.removeItem(at: url)
                if let error {
                    continuation.resume(throwing: SyncFailure(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func refresh(pairing: Pairing, myName: String) async throws -> RefreshResult {
        let connected = await MainActor.run { !(session?.connectedPeers.isEmpty ?? true) }
        if !connected {
            restore(pairing: pairing, myName: myName)
        }
        return RefreshResult()
    }

    func stop() {
        DispatchQueue.main.async {
            self.resumeJoin(.failure(SyncFailure("Stopped looking.")))
            self.stopLocked()
        }
    }

    private func prepareSession() {
        let peer = loadPeerID(displayName: myName)
        peerID = peer
        let session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session
    }

    private func startAdvertising() {
        guard let peerID else { return }
        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ["code": activeCode, "name": myName],
            serviceType: Self.serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser
    }

    private func startBrowsing() {
        guard let peerID else { return }
        let browser = MCNearbyServiceBrowser(peer: peerID, serviceType: Self.serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser
    }

    private func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
    }

    private func stopLocked() {
        joinTimeout?.cancel()
        joinTimeout = nil
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session?.disconnect()
        session = nil
        partials.removeAll()
    }

    private func resumeJoin(_ result: Result<Pairing, Error>) {
        joinTimeout?.cancel()
        joinTimeout = nil
        let continuation = joinContinuation
        joinContinuation = nil
        continuation?.resume(with: result)
    }

    private func emit(_ event: SyncEvent) {
        if Thread.isMainThread {
            onEvent?(event)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.onEvent?(event)
            }
        }
    }

    private func sendHello() {
        guard let session, !session.connectedPeers.isEmpty else { return }
        let message = WireMessage(kind: "hello", name: myName, code: activeCode, id: nil, sentAt: nil)
        guard let data = try? JSONCoding.encode(message) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    private func handleHello(_ message: WireMessage, from peerID: MCPeerID) {
        let code = InviteCode.normalize(message.code ?? "")
        guard code == activeCode, code.count == InviteCode.length else { return }
        let name = Self.clean(message.name ?? peerID.displayName)
        partnerName = name
        let pairing = Pairing(
            id: UUID(),
            code: code,
            partnerName: name,
            isConfirmed: true,
            role: role,
            transport: .nearby,
            createdAt: Date()
        )
        emit(.status("Connected to \(name)."))
        emit(.paired(pairing))
        resumeJoin(.success(pairing))
    }

    private func absorb(id: UUID, jpeg: Data? = nil, name: String? = nil, sentAt: Date? = nil) {
        var partial = partials[id] ?? PartialPhoto()
        if let jpeg { partial.jpeg = jpeg }
        if let name { partial.name = name }
        if let sentAt { partial.sentAt = sentAt }
        if let jpeg = partial.jpeg {
            let photo = IncomingPhoto(
                id: id,
                senderName: Self.clean(partial.name ?? partnerName),
                sentAt: partial.sentAt ?? Date(),
                jpeg: jpeg
            )
            partials[id] = nil
            emit(.received(photo))
        } else {
            partials[id] = partial
        }
    }

    private func loadPeerID(displayName: String) -> MCPeerID {
        let defaults = UserDefaults.standard
        let nameKey = "nearby.peerName"
        let dataKey = "nearby.peerData"
        if defaults.string(forKey: nameKey) == displayName,
           let data = defaults.data(forKey: dataKey),
           let peer = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data) {
            return peer
        }
        let peer = MCPeerID(displayName: displayName)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: peer, requiringSecureCoding: true) {
            defaults.set(displayName, forKey: nameKey)
            defaults.set(data, forKey: dataKey)
        }
        return peer
    }

    private static func clean(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = String(trimmed.prefix(40))
        return clipped.isEmpty ? "Friend" : clipped
    }
}

extension NearbySyncTransport: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.sendHello()
            case .notConnected:
                self.emit(.status("Disconnected. Open Wallpaper Swap on both phones to reconnect."))
            case .connecting:
                self.emit(.status("Connecting…"))
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONCoding.decode(WireMessage.self, from: data) else { return }
        DispatchQueue.main.async {
            switch message.kind {
            case "hello":
                self.handleHello(message, from: peerID)
            case "photo":
                guard let id = message.id else { return }
                self.absorb(id: id, name: message.name, sentAt: message.sentAt)
            default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {
        if let error {
            emit(.failed(error.localizedDescription))
            return
        }
        guard let localURL else { return }
        // The system deletes localURL as soon as this method returns.
        let data: Data
        do {
            data = try Data(contentsOf: localURL)
        } catch {
            emit(.failed("The photo arrived incomplete."))
            return
        }
        let stem = resourceName.replacingOccurrences(of: ".jpg", with: "")
        let id = UUID(uuidString: stem) ?? UUID()
        DispatchQueue.main.async {
            self.absorb(id: id, jpeg: data)
        }
    }
}

extension NearbySyncTransport: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        DispatchQueue.main.async {
            invitationHandler(true, self.session)
        }
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        emit(.failed("Couldn't advertise on the local network. \(error.localizedDescription)"))
    }
}

extension NearbySyncTransport: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            let code = InviteCode.normalize(info?["code"] ?? "")
            guard code == self.seekingCode, let session = self.session else { return }
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 25)
            if let name = info?["name"] {
                self.partnerName = Self.clean(name)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.resumeJoin(.failure(SyncFailure("Couldn't search the local network. \(error.localizedDescription)")))
            self.emit(.failed(error.localizedDescription))
        }
    }
}
