/// A single connected Steam account (own Web-API key + the SteamID64 it was
/// used to sign into). The library can merge games from several of these so
/// a user with more than one Steam account sees one combined library.
class SteamAccount {
  final String steamId;
  final String apiKey;
  final String personaName;
  final String avatarUrl;

  SteamAccount({
    required this.steamId,
    required this.apiKey,
    required this.personaName,
    required this.avatarUrl,
  });

  factory SteamAccount.fromJson(Map<String, dynamic> json) => SteamAccount(
    steamId: json['steamId'] as String,
    apiKey: json['apiKey'] as String,
    personaName: (json['personaName'] as String?) ?? 'Steam-Nutzer',
    avatarUrl: (json['avatarUrl'] as String?) ?? '',
  );

  Map<String, dynamic> toJson() => {
    'steamId': steamId,
    'apiKey': apiKey,
    'personaName': personaName,
    'avatarUrl': avatarUrl,
  };
}
