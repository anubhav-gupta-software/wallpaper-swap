//
//  CloudKitSyncTransport.swift
//  WallpaperSwap
//

import CloudKit
import Foundation

/// Public-database rooms keyed by the invite code. Anyone with the code can
/// read the photos, so treat the code like a password. The development
/// schema needs a Queryable index on Photo.room — see the README.
///
/// This target links CloudKit but does not enable the iCloud entitlement.
/// Calls fail clearly until a paid account signs WallpaperSwap-iCloud.entitlements.
final class CloudKitSyncTransport: SyncTransport {
    var onEvent: ((SyncEvent) -> Void)?

    private let roomType = "Room"
    private let photoType = "Photo"

    func restore(pairing: Pairing, myName: String) {
        emit(.status(pairing.isConfirmed
            ? "iCloud will refresh when you open the app."
            : "Waiting for your friend to enter \(InviteCode.grouped(pairing.code)) in iCloud."))
    }

    func beginHosting(myName: String) async throws -> String {
        let database = try await database()
        let code = InviteCode.make()
        let record = CKRecord(recordType: roomType, recordID: CKRecord.ID(recordName: code))
        record.setObject(code as NSString, forKey: "code")
        record.setObject(Self.clean(myName) as NSString, forKey: "hostName")
        record.setObject(Date() as NSDate, forKey: "createdAt")
        do {
            _ = try await database.save(record)
        } catch {
            throw SyncFailure(Self.describe(error))
        }
        emit(.status("Share this code. Your friend needs iCloud mode too."))
        return code
    }

    func join(code: String, myName: String) async throws -> Pairing {
        let normalized = InviteCode.normalize(code)
        guard normalized.count == InviteCode.length else {
            throw SyncFailure("Enter the 6-character code.")
        }
        let database = try await database()
        let record: CKRecord
        do {
            record = try await database.record(for: CKRecord.ID(recordName: normalized))
        } catch {
            throw SyncFailure(Self.describe(error))
        }
        let host = (record["hostName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hostName = host.isEmpty ? "Your friend" : host
        // The guest writes their own record. They can't edit the host's Room,
        // and fetching this by record name needs no query index.
        let guestID = CKRecord.ID(recordName: "\(normalized)-guest")
        do {
            _ = try await database.record(for: guestID)
        } catch let error as CKError where error.code == .unknownItem {
            let guestRecord = CKRecord(recordType: "Guest", recordID: guestID)
            guestRecord.setObject(Self.clean(myName) as NSString, forKey: "guestName")
            guestRecord.setObject(normalized as NSString, forKey: "room")
            do {
                _ = try await database.save(guestRecord)
            } catch {
                throw SyncFailure(Self.describe(error))
            }
        } catch {
            throw SyncFailure(Self.describe(error))
        }
        return Pairing(
            id: UUID(),
            code: normalized,
            partnerName: hostName,
            isConfirmed: true,
            role: .guest,
            transport: .iCloud,
            createdAt: Date()
        )
    }

    func send(jpeg: Data, id: UUID, myName: String, pairing: Pairing) async throws {
        guard jpeg.count < 20_000_000 else {
            throw SyncFailure("That photo is too large for iCloud.")
        }
        let database = try await database()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(id.uuidString).jpg")
        try jpeg.write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }
        let record = CKRecord(recordType: photoType, recordID: CKRecord.ID(recordName: id.uuidString))
        record.setObject(pairing.code as NSString, forKey: "room")
        record.setObject(Self.clean(myName) as NSString, forKey: "sender")
        record.setObject(Date() as NSDate, forKey: "sentAt")
        record.setObject(CKAsset(fileURL: url), forKey: "image")
        do {
            _ = try await database.save(record)
        } catch {
            throw SyncFailure(Self.describe(error))
        }
    }

    func refresh(pairing: Pairing, myName: String) async throws -> RefreshResult {
        let database = try await database()
        var result = RefreshResult()
        if pairing.role == .host, !pairing.isConfirmed {
            if let record = try? await database.record(for: CKRecord.ID(recordName: "\(pairing.code)-guest")),
               let guest = record["guestName"] as? String,
               !guest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                var updated = pairing
                updated.partnerName = Self.clean(guest)
                updated.isConfirmed = true
                result.pairing = updated
            }
        }
        let predicate = NSPredicate(format: "room == %@", pairing.code)
        let query = CKQuery(recordType: photoType, predicate: predicate)
        let matches: [(CKRecord.ID, Result<CKRecord, Error>)]
        do {
            let response = try await database.records(matching: query, resultsLimit: 60)
            matches = response.matchResults
        } catch {
            throw SyncFailure(Self.describe(error))
        }
        for (_, outcome) in matches {
            guard case .success(let record) = outcome,
                  let asset = record["image"] as? CKAsset,
                  let fileURL = asset.fileURL,
                  let data = try? Data(contentsOf: fileURL) else {
                continue
            }
            let id = UUID(uuidString: record.recordID.recordName) ?? UUID()
            let sender = Self.clean((record["sender"] as? String) ?? pairing.displayName)
            let sentAt = (record["sentAt"] as? Date) ?? record.creationDate ?? Date()
            if sender == Self.clean(myName) { continue }
            result.photos.append(IncomingPhoto(id: id, senderName: sender, sentAt: sentAt, jpeg: data))
        }
        return result
    }

    func stop() {}

    private func database() async throws -> CKDatabase {
        let container = CKContainer(identifier: AppGroup.cloudKitContainerID)
        let status: CKAccountStatus
        do {
            status = try await container.accountStatus()
        } catch {
            throw SyncFailure(Self.describe(error))
        }
        switch status {
        case .available:
            return container.publicCloudDatabase
        case .noAccount:
            throw SyncFailure("Sign in to iCloud on this iPhone, then try again.")
        case .restricted:
            throw SyncFailure("iCloud is restricted on this iPhone.")
        case .couldNotDetermine, .temporarilyUnavailable:
            throw SyncFailure("iCloud isn't reachable right now.")
        @unknown default:
            throw SyncFailure("iCloud isn't available.")
        }
    }

    private func emit(_ event: SyncEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }

    private static func clean(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = String(trimmed.prefix(40))
        return clipped.isEmpty ? "Friend" : clipped
    }

    private static func describe(_ error: Error) -> String {
        if let failure = error as? SyncFailure { return failure.message }
        guard let ck = error as? CKError else { return error.localizedDescription }
        switch ck.code {
        case .unknownItem:
            return "That code doesn't exist in iCloud yet."
        case .notAuthenticated:
            return "Sign in to iCloud on this iPhone."
        case .missingEntitlement, .permissionFailure, .badContainer, .managedAccountRestricted:
            return "iCloud sync isn't enabled for this install. It needs a paid Apple Developer Program membership and the iCloud entitlements. Nearby pairing works without that."
        case .invalidArguments, .serverRejectedRequest:
            return "CloudKit rejected the request. In the CloudKit console, mark Photo.room as Queryable. The README has the steps."
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return "iCloud isn't reachable right now."
        default:
            if ck.localizedDescription.localizedCaseInsensitiveContains("entitlement") {
                return "iCloud sync isn't enabled for this install. It needs a paid Apple Developer Program membership and the iCloud entitlements. Nearby pairing works without that."
            }
            return ck.localizedDescription
        }
    }
}
