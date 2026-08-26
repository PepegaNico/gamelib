import Foundation

/// One owned Steam game. Raw-JSON parsing lives in SteamWebAPI (a private
/// DTO there maps to this clean struct), matching the Dart model's
/// `fromJson` factory pattern.
struct SteamGame: Identifiable, Equatable, Sendable {
    var appId: Int
    var name: String
    var playtimeForeverMinutes: Int
    var playtime2WeeksMinutes: Int
    var lastPlayed: Date?
    var steamId: String

    var id: String { "steam:\(appId)" }
    var playtimeForeverHours: Double { Double(playtimeForeverMinutes) / 60 }
    var hasBeenPlayed: Bool { playtimeForeverMinutes > 0 }

    var headerImageURL: URL {
        URL(string: "https://cdn.akamai.steamstatic.com/steam/apps/\(appId)/header.jpg")!
    }

    var storePageURL: URL {
        URL(string: "https://store.steampowered.com/app/\(appId)/")!
    }

    /// Opens the Steam client and launches the game directly.
    var launchURL: URL {
        URL(string: "steam://run/\(appId)")!
    }
}
