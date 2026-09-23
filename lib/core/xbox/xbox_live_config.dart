/// Microsoft sign-in for Xbox Live needs an app registration of our own in
/// the Azure portal (free) — Microsoft doesn't allow borrowing another
/// app's client id. Until [clientId] is filled in, the Xbox account login
/// is hidden; locally installed Xbox/Microsoft Store games still work.
///
/// Setup (once, ~5 minutes):
/// 1. https://portal.azure.com → "App registrations" → "New registration".
/// 2. Name "GameZer", supported account types: "Personal Microsoft
///    accounts only". No redirect URI.
/// 3. Authentication → Advanced settings → "Allow public client flows": Yes.
/// 4. Copy the "Application (client) ID" into [clientId] below.
class XboxLiveConfig {
  static const clientId = '975d0170-510a-48ad-9d90-5d7ec25cf3d8';

  static bool get isConfigured => clientId.isNotEmpty;
}
