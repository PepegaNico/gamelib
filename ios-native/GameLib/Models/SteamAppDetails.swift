import Foundation

/// Storefront details for one Steam app — only the fields the Library
/// screen's filters need (controller support, German-language flag) plus a
/// few extras for a later Game Detail screen. Raw-JSON parsing lives in
/// SteamStoreAPI.
struct SteamAppDetails: Equatable, Sendable {
    var name: String?
    /// "game", "dlc", "demo", "music", "mod", "video", …
    var type: String?
    var shortDescription: String?
    var genres: [String]
    var developers: [String]
    var publishers: [String]
    var releaseDate: String?
    var metacriticScore: Int?
    var metacriticUrl: String?
    var fullControllerSupport: Bool
    var supportsGerman: Bool
    var screenshotUrls: [String]
}
