import Foundation
import Observation

/// Loads and merges owned Steam games, and progressively backfills
/// storefront details (genres/controller-support/language) in the
/// background so filters work without blocking the initial load. Ports the
/// Flutter app's LibraryState — itch.io/Epic merge points are intentionally
/// left as TODOs for their own later phases.
@Observable
final class LibraryViewModel {
    private let webAPI = SteamWebAPI()
    private let storeAPI = SteamStoreAPI()
    private static let prefetchConcurrency = 8

    var steamGames: [SteamGame] = []
    var isLoading = false
    var errorMessage: String?

    var appDetailsCache: [Int: SteamAppDetails] = [:]
    var isPrefetchingDetails = false
    var prefetchedCount = 0

    // TODO(phase-2/3): merge in itch.io and Epic games once those features land.
    var games: [SteamGame] { steamGames }

    /// Loads and merges owned games from every connected Steam account. A
    /// game owned on more than one account is shown once, keeping the copy
    /// with the most playtime.
    func load(accounts: [SteamAccount]) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let api = webAPI
        var anySucceeded = false
        var perAccount: [[SteamGame]] = []

        await withTaskGroup(of: [SteamGame]?.self) { group in
            for account in accounts {
                group.addTask {
                    try? await api.getOwnedGames(apiKey: account.apiKey, steamId: account.steamId)
                }
            }
            for await result in group {
                // nil means the call threw for that account; a successful
                // call that happens to return zero games is still a success
                // (a brand-new/empty Steam library), so this must not be
                // conflated with "isEmpty" the way a naive `try?` fold would.
                if let games = result {
                    anySucceeded = true
                    perAccount.append(games)
                }
            }
        }

        var merged: [Int: SteamGame] = [:]
        for accountGames in perAccount {
            for game in accountGames {
                if let existing = merged[game.appId],
                   existing.playtimeForeverMinutes >= game.playtimeForeverMinutes {
                    continue
                }
                merged[game.appId] = game
            }
        }
        steamGames = merged.values.sorted { $0.playtimeForeverMinutes > $1.playtimeForeverMinutes }

        if !anySucceeded && !accounts.isEmpty {
            errorMessage = "Bibliothek konnte nicht geladen werden."
        } else if steamGames.isEmpty {
            errorMessage = """
            Keine Spiele gefunden. Prüfe, ob dein Steam-Profil und deine \
            Spieledetails auf "Öffentlich" gestellt sind (Steam-Profil → \
            Datenschutzeinstellungen).
            """
        }
    }

    func prefetchAppDetails() async {
        if isPrefetchingDetails || steamGames.isEmpty { return }
        isPrefetchingDetails = true
        prefetchedCount = 0
        defer { isPrefetchingDetails = false }

        let api = storeAPI
        var index = 0
        while index < steamGames.count {
            let end = min(index + Self.prefetchConcurrency, steamGames.count)
            let batch = Array(steamGames[index..<end])

            await withTaskGroup(of: (Int, SteamAppDetails?).self) { group in
                for game in batch {
                    group.addTask {
                        (game.appId, await api.getAppDetails(appId: game.appId))
                    }
                }
                for await (appId, details) in group {
                    if let details { appDetailsCache[appId] = details }
                }
            }

            prefetchedCount += batch.count
            index = end
        }
    }
}
