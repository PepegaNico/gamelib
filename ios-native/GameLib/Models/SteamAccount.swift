import Foundation

/// A single connected Steam account (own Web API key + the SteamID64 it was
/// used to sign into). Mirrors the Flutter app's SteamAccount model so the
/// same shape round-trips through Cloud-Sync/QR transfer once that phase
/// lands — field names intentionally match the Dart `toJson()`/`fromJson()`.
struct SteamAccount: Codable, Identifiable, Equatable, Sendable {
    var steamId: String
    var apiKey: String
    var personaName: String
    var avatarUrl: String

    var id: String { steamId }
}
