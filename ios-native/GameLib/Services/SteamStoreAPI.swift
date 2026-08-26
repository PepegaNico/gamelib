import Foundation

/// Undocumented Steam storefront API — no key required. Used to backfill
/// genres/controller-support/German-language flags the Owned Games API
/// doesn't provide. Failures are swallowed (return nil), matching the Dart
/// version — a missing storefront entry shouldn't break the library.
struct SteamStoreAPI: Sendable {
    func getAppDetails(appId: Int) async -> SteamAppDetails? {
        var components = URLComponents(string: "https://store.steampowered.com/api/appdetails")!
        components.queryItems = [
            URLQueryItem(name: "appids", value: "\(appId)"),
            URLQueryItem(name: "l", value: "german"),
        ]
        guard let url = components.url else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            let decoded = try JSONDecoder().decode([String: AppDetailsEnvelope].self, from: data)
            guard let entry = decoded["\(appId)"], entry.success, let raw = entry.data else {
                return nil
            }
            return raw.toSteamAppDetails()
        } catch {
            return nil
        }
    }
}

// MARK: - Raw API response shapes

private struct AppDetailsEnvelope: Decodable {
    let success: Bool
    let data: RawAppDetails?
}

private struct RawAppDetails: Decodable {
    let name: String?
    let type: String?
    let short_description: String?
    let genres: [RawNamedEntry]?
    let categories: [RawNamedEntry]?
    let developers: [String]?
    let publishers: [String]?
    let release_date: RawReleaseDate?
    let metacritic: RawMetacritic?
    let supported_languages: String?
    let screenshots: [RawScreenshot]?

    func toSteamAppDetails() -> SteamAppDetails {
        let genreNames = genres?.map(\.description) ?? []
        let categoryNames = categories?.map(\.description) ?? []
        let languages = (supported_languages ?? "").lowercased()

        return SteamAppDetails(
            name: name,
            type: type,
            shortDescription: short_description,
            genres: genreNames,
            developers: developers ?? [],
            publishers: publishers ?? [],
            releaseDate: release_date?.date,
            metacriticScore: metacritic?.score,
            metacriticUrl: metacritic?.url,
            fullControllerSupport: categoryNames.contains { $0.lowercased().contains("controller") },
            supportsGerman: languages.contains("german") || languages.contains("deutsch"),
            screenshotUrls: Array((screenshots ?? []).map(\.path_thumbnail).prefix(6))
        )
    }
}

private struct RawNamedEntry: Decodable {
    let description: String
}

private struct RawReleaseDate: Decodable {
    let date: String?
}

private struct RawMetacritic: Decodable {
    let score: Int?
    let url: String?
}

private struct RawScreenshot: Decodable {
    let path_thumbnail: String
}
