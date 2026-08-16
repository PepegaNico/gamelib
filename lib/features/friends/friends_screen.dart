import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/steam/steam_friend.dart';
import '../auth/auth_state.dart';
import 'friends_state.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthState>();
    if (auth.apiKey == null || auth.steamId == null) return;
    await context.read<FriendsState>().load(
      apiKey: auth.apiKey!,
      steamId: auth.steamId!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendsState = context.watch<FriendsState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Freunde'),
        actions: [
          IconButton(
            tooltip: 'Aktualisieren',
            onPressed: friendsState.isLoading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(friendsState),
    );
  }

  Widget _buildBody(FriendsState state) {
    if (state.isLoading && state.friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorMessage != null && state.friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(state.errorMessage!, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.builder(
      itemCount: state.friends.length,
      itemBuilder: (context, index) {
        final friend = state.friends[index];
        return ListTile(
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundImage: friend.avatarUrl.isNotEmpty
                    ? NetworkImage(friend.avatarUrl)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _statusColor(friend),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
          title: Text(friend.personaName),
          subtitle: Text(
            friend.isInGame
                ? 'Spielt: ${friend.currentGameName}'
                : friend.state.label,
          ),
        );
      },
    );
  }

  Color _statusColor(SteamFriend friend) {
    if (friend.isInGame) return Colors.greenAccent;
    if (friend.state != SteamPersonaState.offline) {
      return Colors.lightBlueAccent;
    }
    return Colors.grey;
  }
}
