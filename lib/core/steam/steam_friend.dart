enum SteamPersonaState {
  offline(0, 'Offline'),
  online(1, 'Online'),
  busy(2, 'Beschäftigt'),
  away(3, 'Abwesend'),
  snooze(4, 'Inaktiv'),
  lookingToTrade(5, 'Handeln'),
  lookingToPlay(6, 'Suche Mitspieler');

  const SteamPersonaState(this.code, this.label);
  final int code;
  final String label;

  static SteamPersonaState fromCode(int code) =>
      values.firstWhere((s) => s.code == code, orElse: () => offline);
}

class SteamFriend {
  final String steamId;
  final String personaName;
  final String avatarUrl;
  final SteamPersonaState state;
  final String? currentGameName;

  SteamFriend({
    required this.steamId,
    required this.personaName,
    required this.avatarUrl,
    required this.state,
    required this.currentGameName,
  });

  bool get isInGame => currentGameName != null && currentGameName!.isNotEmpty;

  factory SteamFriend.fromJson(Map<String, dynamic> json) {
    return SteamFriend(
      steamId: json['steamid'] as String,
      personaName: (json['personaname'] as String?) ?? 'Steam-Nutzer',
      avatarUrl: (json['avatarfull'] as String?) ?? '',
      state: SteamPersonaState.fromCode((json['personastate'] as int?) ?? 0),
      currentGameName: json['gameextrainfo'] as String?,
    );
  }
}
