/// A game GameZer can see running on this PC because it knows its install
/// folder (installed Epic and Xbox / Microsoft Store games). PlayTracker
/// feeds the recorded play data back through [applyTrackedPlay].
abstract interface class TrackableGame {
  String get id;

  /// Folder the game is installed in; null when not installed here.
  String? get installDirectory;

  void applyTrackedPlay({required DateTime lastPlayed, required int minutes});
}
