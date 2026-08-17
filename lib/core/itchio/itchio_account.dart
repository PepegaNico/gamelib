/// A single connected itch.io account (own API key + the username it
/// belongs to). The library can merge games from several of these so a user
/// with more than one itch.io account sees one combined library.
class ItchioAccount {
  final String apiKey;
  final String username;

  ItchioAccount({required this.apiKey, required this.username});

  factory ItchioAccount.fromJson(Map<String, dynamic> json) => ItchioAccount(
    apiKey: json['apiKey'] as String,
    username: (json['username'] as String?) ?? 'itch.io-Nutzer',
  );

  Map<String, dynamic> toJson() => {'apiKey': apiKey, 'username': username};
}
