import 'dart:convert';

import 'package:http/http.dart' as http;

import 'steam_achievement.dart';
import 'steam_friend.dart';
import 'steam_game.dart';
import 'steam_news_item.dart';

class SteamApiException implements Exception {
  final String message;
  SteamApiException(this.message);
  @override
  String toString() => message;
}

/// Thin wrapper around the Steam Web API. Every call uses the user's own
/// API key — nothing is proxied through a server we run.
class SteamWebApiService {
  static const _base = 'https://api.steampowered.com';

  Future<List<SteamGame>> getOwnedGames({
    required String apiKey,
    required String steamId,
  }) async {
    final uri = Uri.parse('$_base/IPlayerService/GetOwnedGames/v1/').replace(
      queryParameters: {
        'key': apiKey,
        'steamid': steamId,
        'include_appinfo': 'true',
        'include_played_free_games': 'true',
        'format': 'json',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw SteamApiException(
        'Der Steam-API-Key ist ungültig oder wurde gesperrt.',
      );
    }
    if (response.statusCode != 200) {
      throw SteamApiException(
        'Steam hat mit Status ${response.statusCode} geantwortet.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final gamesResponse = body['response'] as Map<String, dynamic>?;
    if (gamesResponse == null || gamesResponse['games'] == null) {
      // Empty response usually means the profile's game details are private.
      return [];
    }

    final games =
        (gamesResponse['games'] as List)
            .cast<Map<String, dynamic>>()
            .map((json) => SteamGame.fromJson(json, steamId: steamId))
            .toList()
          ..sort(
            (a, b) =>
                b.playtimeForeverMinutes.compareTo(a.playtimeForeverMinutes),
          );

    return games;
  }

  Future<({String personaName, String avatarUrl})> getPlayerSummary({
    required String apiKey,
    required String steamId,
  }) async {
    final uri = Uri.parse('$_base/ISteamUser/GetPlayerSummaries/v2/')
        .replace(queryParameters: {'key': apiKey, 'steamids': steamId});

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw SteamApiException(
        'Steam hat mit Status ${response.statusCode} geantwortet.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final players = (body['response']?['players'] as List?) ?? [];
    if (players.isEmpty) {
      throw SteamApiException('Steam-Profil konnte nicht gefunden werden.');
    }

    final player = players.first as Map<String, dynamic>;
    return (
      personaName: (player['personaname'] as String?) ?? 'Steam-Nutzer',
      avatarUrl: (player['avatarfull'] as String?) ?? '',
    );
  }

  /// Returns null if the game has no achievements at all, or the profile's
  /// achievement/game details are private.
  Future<List<SteamAchievement>?> getAchievements({
    required String apiKey,
    required String steamId,
    required int appId,
  }) async {
    final schemaUri = Uri.parse('$_base/ISteamUserStats/GetSchemaForGame/v2/')
        .replace(queryParameters: {'key': apiKey, 'appid': '$appId'});
    final schemaResponse = await http.get(schemaUri);
    if (schemaResponse.statusCode != 200) return null;

    final schemaBody = jsonDecode(schemaResponse.body) as Map<String, dynamic>;
    final schemaAchievements =
        (schemaBody['game']?['availableGameStats']?['achievements'] as List?)
            ?.cast<Map<String, dynamic>>();
    if (schemaAchievements == null || schemaAchievements.isEmpty) return null;

    final progressUri =
        Uri.parse('$_base/ISteamUserStats/GetPlayerAchievements/v1/').replace(
          queryParameters: {
            'key': apiKey,
            'steamid': steamId,
            'appid': '$appId',
          },
        );
    final progressResponse = await http.get(progressUri);
    if (progressResponse.statusCode != 200) return null;

    final progressBody =
        jsonDecode(progressResponse.body) as Map<String, dynamic>;
    if (progressBody['playerstats']?['success'] != true) return null;

    final achievedByName = <String, bool>{
      for (final a
          in (progressBody['playerstats']['achievements'] as List)
              .cast<Map<String, dynamic>>())
        a['apiname'] as String: (a['achieved'] as int) == 1,
    };

    return schemaAchievements.map((schema) {
        final apiName = schema['name'] as String;
        return SteamAchievement(
          apiName: apiName,
          displayName: (schema['displayName'] as String?) ?? apiName,
          description: (schema['description'] as String?) ?? '',
          achieved: achievedByName[apiName] ?? false,
          iconUrl: (schema['icon'] as String?) ?? '',
          iconGrayUrl: (schema['icongray'] as String?) ?? '',
        );
      }).toList()
      ..sort((a, b) => (b.achieved ? 1 : 0).compareTo(a.achieved ? 1 : 0));
  }

  Future<List<String>> getFriendSteamIds({
    required String apiKey,
    required String steamId,
  }) async {
    final uri = Uri.parse('$_base/ISteamUser/GetFriendList/v1/').replace(
      queryParameters: {
        'key': apiKey,
        'steamid': steamId,
        'relationship': 'friend',
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      // Commonly 401 when the friends list itself is private.
      return [];
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final friends = (body['friendslist']?['friends'] as List?) ?? [];
    return friends
        .cast<Map<String, dynamic>>()
        .map((f) => f['steamid'] as String)
        .toList();
  }

  Future<List<SteamFriend>> getPlayerSummaries({
    required String apiKey,
    required List<String> steamIds,
  }) async {
    if (steamIds.isEmpty) return [];

    final results = <SteamFriend>[];
    // The endpoint accepts up to 100 IDs per call.
    for (var i = 0; i < steamIds.length; i += 100) {
      final batch = steamIds.sublist(
        i,
        i + 100 > steamIds.length ? steamIds.length : i + 100,
      );
      final uri = Uri.parse(
        '$_base/ISteamUser/GetPlayerSummaries/v2/',
      ).replace(queryParameters: {'key': apiKey, 'steamids': batch.join(',')});
      final response = await http.get(uri);
      if (response.statusCode != 200) continue;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final players = (body['response']?['players'] as List?) ?? [];
      results.addAll(
        players.cast<Map<String, dynamic>>().map(SteamFriend.fromJson),
      );
    }
    return results;
  }

  /// No API key required — this is a public endpoint.
  Future<List<SteamNewsItem>> getNewsForApp({
    required int appId,
    required String gameName,
    int count = 5,
  }) async {
    final uri =
        Uri.parse(
          'https://api.steampowered.com/ISteamNews/GetNewsForApp/v0002/',
        ).replace(
          queryParameters: {
            'appid': '$appId',
            'count': '$count',
            'maxlength': '400',
            'format': 'json',
          },
        );

    final response = await http.get(uri);
    if (response.statusCode != 200) return [];

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['appnews']?['newsitems'] as List?) ?? [];
    return items
        .cast<Map<String, dynamic>>()
        .map((json) => SteamNewsItem.fromJson(json, gameName: gameName))
        .toList();
  }
}
