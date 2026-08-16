class SteamAchievement {
  final String apiName;
  final String displayName;
  final String description;
  final bool achieved;
  final String iconUrl;
  final String iconGrayUrl;

  SteamAchievement({
    required this.apiName,
    required this.displayName,
    required this.description,
    required this.achieved,
    required this.iconUrl,
    required this.iconGrayUrl,
  });
}
