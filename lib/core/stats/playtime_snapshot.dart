class PlaytimeSnapshot {
  final String gameId;
  final String gameName;
  final int playtimeMinutes;

  /// Truncated to midnight — one snapshot per game per day.
  final DateTime date;

  PlaytimeSnapshot({
    required this.gameId,
    required this.gameName,
    required this.playtimeMinutes,
    required this.date,
  });

  factory PlaytimeSnapshot.fromJson(Map<String, dynamic> json) {
    return PlaytimeSnapshot(
      gameId: json['gameId'] as String,
      gameName: json['gameName'] as String,
      playtimeMinutes: json['playtimeMinutes'] as int,
      date: DateTime.parse(json['date'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'gameId': gameId,
    'gameName': gameName,
    'playtimeMinutes': playtimeMinutes,
    'date': date.toIso8601String(),
  };
}
