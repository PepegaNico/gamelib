/// An optional, shared IsThereAnyDeal key baked in at build time via
/// `--dart-define=ITAD_API_KEY=...`, so price comparison works for anyone
/// who downloads the app without them needing their own key. Deliberately
/// kept out of source control entirely — unlike Firebase's web key, this
/// is a personal, rate-limited credential, not something meant to be
/// public. Empty (unset) when the app wasn't built with that define, e.g.
/// any build that doesn't pass --dart-define.
class ItadDefaultKey {
  static const value = String.fromEnvironment('ITAD_API_KEY');
  static bool get isSet => value.isNotEmpty;
}
