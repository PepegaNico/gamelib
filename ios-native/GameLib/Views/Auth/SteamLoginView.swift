import SwiftUI

/// First-run onboarding gate: paste a Steam Web API key, then confirm
/// ownership via Steam's native OpenID sign-in sheet. Two steps because a
/// Web API key has no OAuth equivalent — see AuthViewModel/SteamOpenIDService.
struct SteamLoginView: View {
    @Environment(AuthViewModel.self) private var auth

    @State private var apiKeyInput = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)

                Text("Mit Steam verbinden")
                    .font(.title2.bold())

                if auth.status == .needsLogin {
                    signInStep
                } else {
                    apiKeyStep
                }

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
        }
    }

    private var apiKeyStep: some View {
        VStack(spacing: 12) {
            Text("""
            Erstelle zuerst einen Steam Web-API-Key auf \
            steamcommunity.com/dev/apikey und füge ihn hier ein.
            """)
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            TextField("API-Key", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("Weiter") {
                auth.saveApiKey(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
    }

    private var signInStep: some View {
        VStack(spacing: 12) {
            Text("Jetzt mit deinem Steam-Account anmelden, um den Key zuzuordnen.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if auth.isSigningIn {
                ProgressView()
            } else {
                Button("Mit Steam anmelden") {
                    Task { await auth.signInWithSteam() }
                }
                .buttonStyle(.borderedProminent)
            }

            Button("Anderen API-Key verwenden") {
                auth.removeApiKey()
            }
            .buttonStyle(.plain)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }
}
