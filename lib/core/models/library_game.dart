import 'game_platform.dart';

/// Common shape shared by games from any connected store, so the library
/// grid, filters and sorting don't need to know which platform a game is
/// from. Platform-specific data (achievements, Steam news, …) lives on the
/// concrete implementation and is only used by platform-specific screens.
abstract class LibraryGame {
  String get id;
  String get name;
  GamePlatform get platform;
  String get headerImageUrl;
  String get storePageUrl;

  /// False for stores (like itch.io) that don't expose playtime via their
  /// API — playtimeForeverHours/hasBeenPlayed/lastPlayed are meaningless
  /// then and should be treated as "unknown", not "zero".
  bool get hasPlaytimeData;
  double get playtimeForeverHours;
  bool get hasBeenPlayed;
  DateTime? get lastPlayed;

  /// Label + URL for the primary action button (e.g. "Spiel starten" via a
  /// launcher URI, or "Auf itch.io öffnen" when there's no reliable local
  /// launch mechanism).
  String get primaryActionLabel;
  String get primaryActionUrl;
}
