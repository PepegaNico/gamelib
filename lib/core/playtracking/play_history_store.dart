import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class PlayRecord {
  DateTime lastPlayed;
  int minutes;

  PlayRecord({required this.lastPlayed, this.minutes = 0});

  Map<String, dynamic> toJson() => {
    'lastPlayed': lastPlayed.toUtc().toIso8601String(),
    'minutes': minutes,
  };

  factory PlayRecord.fromJson(Map<String, dynamic> json) => PlayRecord(
    lastPlayed: DateTime.parse(json['lastPlayed'] as String).toLocal(),
    minutes: (json['minutes'] as num?)?.toInt() ?? 0,
  );
}

/// Locally recorded play sessions (game id → last played + minutes), kept
/// in a small JSON file in the app's support folder.
class PlayHistoryStore {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}play_history.json');
  }

  Future<Map<String, PlayRecord>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return {};
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return json.map(
        (id, record) =>
            MapEntry(id, PlayRecord.fromJson(record as Map<String, dynamic>)),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, PlayRecord> history) async {
    final file = await _file();
    await file.writeAsString(
      jsonEncode(history.map((id, record) => MapEntry(id, record.toJson()))),
    );
  }
}
