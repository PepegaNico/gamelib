import AuthenticationServices
import Foundation
import UIKit

enum SteamOpenIDError: LocalizedError {
    case cancelled
    case invalidCallback
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Anmeldung wurde abgebrochen."
        case .invalidCallback:
            return "Ungültige Antwort von Steam."
        case .verificationFailed:
            return "Die Anmeldung konnte nicht bestätigt werden."
        }
    }
}

/// Signs the user in via Steam's OpenID 2.0 login inside a native auth
/// session (ASWebAuthenticationSession). Steam has no OAuth/scopes — OpenID
/// only proves "this session belongs to SteamID X"; a separate, manually
/// obtained Steam Web API key is still required for the actual API calls
/// (see SteamLoginView's two-step flow — this mirrors the Flutter app's
/// AuthState exactly, only the callback transport changed).
///
/// Steam does not perform realm HTML-discovery verification, so a custom
/// URL scheme works directly as both realm and return_to — the same trick
/// several other third-party Steam clients use. This is genuinely
/// unverified from this environment (no way to run Xcode here); if Steam
/// ever starts rejecting non-http realms, the fallback is a small hosted
/// https redirector that forwards to the custom scheme.
final class SteamOpenIDService: NSObject, ASWebAuthenticationPresentationContextProviding {
    private static let callbackScheme = "gamelib"
    private static let realm = "gamelib://steam-callback"
    private static let returnTo = "gamelib://steam-callback"
    private static let claimedIdPattern = try! NSRegularExpression(
        pattern: #"steamcommunity\.com/openid/id/(\d+)$"#
    )

    private var activeSession: ASWebAuthenticationSession?

    /// Runs the full login flow and returns the authenticated SteamID64, or
    /// throws `.cancelled` if the user dismissed the auth sheet.
    func signIn() async throws -> String {
        var components = URLComponents(string: "https://steamcommunity.com/openid/login")!
        components.queryItems = [
            URLQueryItem(name: "openid.ns", value: "http://specs.openid.net/auth/2.0"),
            URLQueryItem(name: "openid.mode", value: "checkid_setup"),
            URLQueryItem(name: "openid.return_to", value: Self.returnTo),
            URLQueryItem(name: "openid.realm", value: Self.realm),
            URLQueryItem(
                name: "openid.identity",
                value: "http://specs.openid.net/auth/2.0/identifier_select"
            ),
            URLQueryItem(
                name: "openid.claimed_id",
                value: "http://specs.openid.net/auth/2.0/identifier_select"
            ),
        ]
        guard let url = components.url else { throw SteamOpenIDError.invalidCallback }

        let callbackURL = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackScheme
            ) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                    return
                }
                if let authError = error as? ASWebAuthenticationSessionError,
                   authError.code == .canceledLogin {
                    continuation.resume(throwing: SteamOpenIDError.cancelled)
                    return
                }
                continuation.resume(throwing: error ?? SteamOpenIDError.invalidCallback)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = true
            activeSession = session
            DispatchQueue.main.async {
                session.start()
            }
        }

        let params = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let dict = Dictionary(uniqueKeysWithValues: params.map { ($0.name, $0.value ?? "") })

        guard dict["openid.mode"] == "id_res" else { throw SteamOpenIDError.verificationFailed }
        guard try await verify(params: dict) else { throw SteamOpenIDError.verificationFailed }

        let claimedId = dict["openid.claimed_id"] ?? ""
        let range = NSRange(claimedId.startIndex..., in: claimedId)
        guard let match = Self.claimedIdPattern.firstMatch(in: claimedId, range: range),
              let steamIdRange = Range(match.range(at: 1), in: claimedId) else {
            throw SteamOpenIDError.invalidCallback
        }
        return String(claimedId[steamIdRange])
    }

    /// Steam OpenID has no shared secret — validation means echoing the
    /// signed params back to Steam with mode=check_authentication and
    /// trusting its "is_valid:true" response.
    private func verify(params: [String: String]) async throws -> Bool {
        var verifyParams = params
        verifyParams["openid.mode"] = "check_authentication"

        var request = URLRequest(url: URL(string: "https://steamcommunity.com/openid/login")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = verifyParams.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        }.joined(separator: "&")
        request.httpBody = Data(body.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { return false }
        return String(data: data, encoding: .utf8)?.contains("is_valid:true") ?? false
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
