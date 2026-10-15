//
//  Models.swift
//  WallpaperSwap
//

import Foundation

enum SyncMode: String, Codable, CaseIterable, Identifiable {
    case local
    case nearby
    case iCloud

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: "This iPhone"
        case .nearby: "Nearby"
        case .iCloud: "iCloud"
        }
    }

    var blurb: String {
        switch self {
        case .local:
            "Try the whole flow on your own phone. Nothing leaves this iPhone."
        case .nearby:
            "Pair with a friend on the same Wi-Fi. Works with a free Apple ID."
        case .iCloud:
            "Sync through CloudKit when you're apart. Needs a paid developer account."
        }
    }
}

enum PairRole: String, Codable {
    case host
    case guest
    case preview
}

struct Pairing: Codable, Equatable, Identifiable {
    var id: UUID
    var code: String
    var partnerName: String
    var isConfirmed: Bool
    var role: PairRole
    var transport: SyncMode
    var createdAt: Date

    var displayName: String {
        let trimmed = partnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Your friend" : trimmed
    }
}

enum SwapDirection: String, Codable {
    case sent
    case received
}

struct Swap: Codable, Equatable, Identifiable {
    var id: UUID
    var direction: SwapDirection
    var createdAt: Date
    var personName: String
    var imageFile: String
    var mirroredToMyScreen: Bool
}

struct CurrentWallpaper: Codable, Equatable {
    var caption: String
    var date: Date
    var swapID: UUID
}

struct Manifest: Codable, Equatable {
    var pairing: Pairing?
    var swaps: [Swap]

    static let empty = Manifest(pairing: nil, swaps: [])
}

enum InviteCode {
    static let length = 6
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func make() -> String {
        var code = ""
        while code.count < length {
            if let next = alphabet.randomElement() {
                code.append(next)
            }
        }
        return code
    }

    static func normalize(_ raw: String) -> String {
        let filtered = raw.uppercased().filter { alphabet.contains($0) }
        return String(filtered.prefix(length))
    }

    static func grouped(_ code: String) -> String {
        let chars = Array(normalize(code))
        guard chars.count > 3 else { return String(chars) }
        return "\(String(chars.prefix(3))) \(String(chars.dropFirst(3)))"
    }
}
