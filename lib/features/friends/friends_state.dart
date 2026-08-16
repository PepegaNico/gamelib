import 'package:flutter/foundation.dart';

import '../../core/steam/steam_friend.dart';
import '../../core/steam/steam_web_api_service.dart';

class FriendsState extends ChangeNotifier {
  FriendsState({SteamWebApiService? webApiService})
    : _webApiService = webApiService ?? SteamWebApiService();

  final SteamWebApiService _webApiService;

  List<SteamFriend> friends = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> load({required String apiKey, required String steamId}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final ids = await _webApiService.getFriendSteamIds(
        apiKey: apiKey,
        steamId: steamId,
      );
      if (ids.isEmpty) {
        friends = [];
        errorMessage =
            'Keine Freunde gefunden. Prüfe, ob deine Freundesliste auf Steam '
            'öffentlich sichtbar ist.';
      } else {
        friends = await _webApiService.getPlayerSummaries(
          apiKey: apiKey,
          steamIds: ids,
        );
        friends.sort((a, b) {
          int rank(SteamFriend f) =>
              f.isInGame ? 0 : (f.state.code != 0 ? 1 : 2);
          final rankCompare = rank(a).compareTo(rank(b));
          if (rankCompare != 0) return rankCompare;
          return a.personaName.toLowerCase().compareTo(
            b.personaName.toLowerCase(),
          );
        });
      }
    } catch (e) {
      errorMessage = 'Freundesliste konnte nicht geladen werden: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
