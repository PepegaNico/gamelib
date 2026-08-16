import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/epic/epic_game.dart';
import '../../core/models/library_game.dart';
import '../epic/epic_launch.dart';
import 'game_details_dispatch.dart';

Future<void> showBacklogPicker(BuildContext context, List<LibraryGame> games) {
  return showDialog(
    context: context,
    builder: (_) => _BacklogPickerDialog(games: games),
  );
}

class _BacklogPickerDialog extends StatefulWidget {
  const _BacklogPickerDialog({required this.games});

  final List<LibraryGame> games;

  @override
  State<_BacklogPickerDialog> createState() => _BacklogPickerDialogState();
}

class _BacklogPickerDialogState extends State<_BacklogPickerDialog> {
  final _random = Random();
  late List<LibraryGame> _pool;
  late LibraryGame _pick;

  @override
  void initState() {
    super.initState();
    final unplayed = widget.games
        .where((g) => !g.hasPlaytimeData || !g.hasBeenPlayed)
        .toList();
    _pool = unplayed.isNotEmpty ? unplayed : widget.games;
    _pick = _pool[_random.nextInt(_pool.length)];
  }

  void _reroll() {
    setState(() => _pick = _pool[_random.nextInt(_pool.length)]);
  }

  Future<void> _launch() async {
    final pick = _pick;
    if (pick is EpicGame) {
      await launchEpicGame(context, pick);
      return;
    }
    await launchUrl(Uri.parse(pick.primaryActionUrl));
  }

  @override
  Widget build(BuildContext context) {
    final isBacklogPick = !_pick.hasPlaytimeData || !_pick.hasBeenPlayed;

    return AlertDialog(
      title: const Text('Was soll ich heute spielen?'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isBacklogPick)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Kein ungespieltes Spiel gefunden – hier ist eine zufällige Wahl aus deiner Bibliothek.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 460 / 215,
                child: _pick.headerImageUrl.isEmpty
                    ? Container(
                        color: _pick.platform.color,
                        alignment: Alignment.center,
                        child: Icon(
                          _pick.platform.icon,
                          size: 40,
                          color: Colors.white24,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: _pick.headerImageUrl,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _pick.name,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton.icon(
          onPressed: _pool.length > 1 ? _reroll : null,
          icon: const Icon(Icons.casino_outlined),
          label: const Text('Nochmal würfeln'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                pushGameDetails(context, _pick);
              },
              child: const Text('Details'),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: _launch,
              icon: const Icon(Icons.play_arrow),
              label: Text(_pick.primaryActionLabel),
            ),
          ],
        ),
      ],
    );
  }
}
