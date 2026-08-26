import Foundation

enum SteamAPIError: LocalizedError {
    case invalidKey
    case httpStatus(Int)
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Der Steam-API-Key ist ungültig oder wurde gesperrt."
        case .httpStatus(let code):
            return "Steam hat mit Status \(code) geantwortet."
        case .profileNotFound:
            return "Steam-Profil konnte nicht gefunden werden."
        }
    }
}

/// Thin wrapper around the Steam Web API — every call uses the user's own
/// API key, nothing is proxied through a server we run.
struct SteamWebAPI: Sendable {
    private static let base = "https://api.steampowered.com"

    func getOwnedGames(apiKey: String, steamId: String) async throws -> [SteamGame] {
        var components = URLComponents(string: "\(Self.base)/IPlayerService/GetOwnedGames/v1/")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "steamid", value: steamId),
            URLQueryItem(name: "include_appinfo", value: "true"),
            URLQueryItem(name: "include_played_free_games", value: "true"),
            URLQueryItem(name: "format", value: "json"),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 || status == 403 { throw SteamAPIError.invalidKey }
        if status != 200 { throw SteamAPIError.httpStatus(status) }

        let decoded = try JSONDecoder().decode(OwnedGamesResponse.self, from: data)
        guard let rawGames = decoded.response.games else { return [] }

        let games = rawGames.map { $0.toSteamGame(steamId: steamId) }
        return games.sorted { $0.playtimeForeverMinutes > $1.playtimeForeverMinutes }
    }

    func getPlayerSummary(
        apiKey: String,
        steamId: String
    ) async throws -> (personaName: String, avatarUrl: String) {
        var components = URLComponents(string: "\(Self.base)/ISteamUser/GetPlayerSummaries/v2/")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "steamids", value: steamId),
        ]

        let (data, response) = try await URLSession.shared.data(from: components.url!)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status != 200 { throw SteamAPIError.httpStatus(status) }

        let decoded = try JSONDecoder().decode(PlayerSummariesResponse.self, from: data)
        guard let player = decoded.response.players.first else {
            throw SteamAPIError.profileNotFound
        }
        return (player.personaname ?? "Steam-Nutzer", player.avatarfull ?? "")
    }
}

// MARK: - Raw API response shapes

private struct OwnedGamesResponse: Decodable {
    let response: OwnedGamesInner
}

private struct OwnedGamesInner: Decodable {
    let games: [RawOwnedGame]?
}

private struct RawOwnedGame: Decodable {
    let appid: Int
    let name: String?
    let playtime_forever: Int?
    let playtime_2weeks: Int?
    let rtime_last_played: Int?

    func toSteamGame(steamId: String) -> SteamGame {
        var lastPlayed: Date?
        if let epoch = rtime_last_played, epoch > 0 {
            lastPlayed = Date(timeIntervalSince1970: TimeInterval(epoch))
        }
        return SteamGame(
            appId: appid,
            name: name ?? "Unbekanntes Spiel",
            playtimeForeverMinutes: playtime_forever ?? 0,
            playtime2WeeksMinutes: playtime_2weeks ?? 0,
            lastPlayed: lastPlayed,
            steamId: steamId
        )
    }
}

private struct PlayerSummariesResponse: Decodable {
    let response: PlayerSummariesInner
}

private struct PlayerSummariesInner: Decodable {
    let players: [RawPlayer]
}

private struct RawPlayer: Decodable {
    let personaname: String?
    let avatarfull: String?
}
