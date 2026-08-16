class SteamNewsItem {
  final int appId;
  final String gameName;
  final String title;
  final String url;
  final String contents;
  final DateTime date;

  SteamNewsItem({
    required this.appId,
    required this.gameName,
    required this.title,
    required this.url,
    required this.contents,
    required this.date,
  });

  factory SteamNewsItem.fromJson(
    Map<String, dynamic> json, {
    required String gameName,
  }) {
    final rawContents = (json['contents'] as String?) ?? '';
    final plainContents = rawContents
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'https?://\S+'), '')
        .trim();
    return SteamNewsItem(
      appId: json['appid'] as int,
      gameName: gameName,
      title: (json['title'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
      contents: plainContents.length > 220
          ? '${plainContents.substring(0, 220)}…'
          : plainContents,
      date: DateTime.fromMillisecondsSinceEpoch(
        ((json['date'] as int?) ?? 0) * 1000,
      ),
    );
  }
}
