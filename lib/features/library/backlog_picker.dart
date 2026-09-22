import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_theme.dart';
import '../../core/epic/epic_game.dart';
import '../../core/models/library_game.dart';
import '../epic/epic_launch.dart';
import 'game_details_dispatch.dart';

Future<void> showBacklogPicker(BuildContext context, List<LibraryGame> games) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BacklogPickerDialog(games: games),
  );
}

const double _reelItemWidth = 130;
const double _reelItemSpacing = 8;
const double _reelStep = _reelItemWidth + _reelItemSpacing;
const double _reelViewportWidth = 400;
const double _reelViewportHeight = 76;
const int _reelFillerCount = 46;
const int _reelTrailingCount = 6;
const Duration _reelSpinDuration = Duration(milliseconds: 6000);

class _BacklogPickerDialog extends StatefulWidget {
  const _BacklogPickerDialog({required this.games});

  final List<LibraryGame> games;

  @override
  State<_BacklogPickerDialog> createState() => _BacklogPickerDialogState();
}

class _BacklogPickerDialogState extends State<_BacklogPickerDialog>
    with SingleTickerProviderStateMixin {
  final _random = Random();
  final _scrollController = ScrollController();
  late final AnimationController _controller;

  late List<LibraryGame> _pool;
  late List<LibraryGame> _reel;
  late int _landingIndex;
  late LibraryGame _pick;
  late Animation<double> _offsetAnimation;
  bool _isSpinning = true;

  @override
  void initState() {
    super.initState();
    final unplayed = widget.games
        .where((g) => !g.hasPlaytimeData || !g.hasBeenPlayed)
        .toList();
    _pool = unplayed.isNotEmpty ? unplayed : widget.games;

    _controller = AnimationController(vsync: this, duration: _reelSpinDuration)
      ..addListener(_onTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _isSpinning = false);
        }
      });

    // Fields only — no setState() here, this runs before the first build.
    _prepareSpin();
    _controller.forward(from: 0);
  }

  /// Picks a winner and builds the reel sequence around it. Called directly
  /// in initState (before the first build) and wrapped in setState() by
  /// _reroll (after a user tap), so it must stay free of setState itself.
  void _prepareSpin() {
    _isSpinning = true;
    _pick = _pool[_random.nextInt(_pool.length)];
    _landingIndex = _reelFillerCount;
    _reel = [
      for (var i = 0; i < _reelFillerCount; i++) widget.games[_random.nextInt(widget.games.length)],
      _pick,
      for (var i = 0; i < _reelTrailingCount; i++) widget.games[_random.nextInt(widget.games.length)],
    ];

    // A CS:GO-style case opening never lands dead-center in the winning
    // slot — a small random offset within it sells the "it really spun"
    // feeling instead of looking mechanically precise.
    final maxJitter = (_reelItemWidth / 2) - 18;
    final jitter = (_random.nextDouble() * 2 - 1) * maxJitter;
    final targetOffset =
        _landingIndex * _reelStep + _reelStep / 2 - _reelViewportWidth / 2 + jitter;

    _offsetAnimation = Tween<double>(begin: 0, end: targetOffset).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo),
    );
  }

  void _onTick() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_offsetAnimation.value);
    }
  }

  void _reroll() {
    if (_isSpinning) return;
    setState(_prepareSpin);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _controller.forward(from: 0);
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
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBacklogPick = !_pick.hasPlaytimeData || !_pick.hasBeenPlayed;

    return AlertDialog(
      backgroundColor: zerSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Was soll ich heute spielen?'),
      content: SizedBox(
        width: _reelViewportWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ReelView(reel: _reel, scrollController: _scrollController),
            const SizedBox(height: 16),
            if (!_isSpinning) ...[
              if (!isBacklogPick)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Kein ungespieltes Spiel gefunden – hier ist eine zufällige Wahl aus deiner Bibliothek.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              Text(
                _pick.name,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ] else
              const SizedBox(height: 20),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton.icon(
          onPressed: !_isSpinning && _pool.length > 1 ? _reroll : null,
          icon: const Icon(Icons.casino_outlined),
          label: const Text('Nochmal würfeln'),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: !_isSpinning
                  ? () {
                      Navigator.of(context).pop();
                      pushGameDetails(context, _pick);
                    }
                  : null,
              child: const Text('Details'),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: !_isSpinning ? _launch : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(_isSpinning ? '…' : _pick.primaryActionLabel),
            ),
          ],
        ),
      ],
    );
  }
}

/// The scrolling strip of covers plus its fixed center pointer — a
/// stateless shell around whatever offset the controller is driven to,
/// same idea as CS:GO's case-opening reel.
class _ReelView extends StatelessWidget {
  const _ReelView({required this.reel, required this.scrollController});

  final List<LibraryGame> reel;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final pointerColor = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: _reelViewportWidth,
      height: _reelViewportHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                  stops: [0.0, 0.08, 0.92, 1.0],
                ).createShader(rect),
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Row(
                    children: [for (final game in reel) _ReelCard(game: game)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ClipPath(
                    clipper: _DownTriangleClipper(),
                    child: Container(width: 14, height: 9, color: pointerColor),
                  ),
                  ClipPath(
                    clipper: _UpTriangleClipper(),
                    child: Container(width: 14, height: 9, color: pointerColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReelCard extends StatelessWidget {
  const _ReelCard({required this.game});

  final LibraryGame game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _reelItemSpacing / 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: _reelItemWidth,
          child: AspectRatio(
            aspectRatio: 460 / 215,
            child: game.headerImageUrl.isEmpty
                ? Container(
                    color: game.platform.color,
                    alignment: Alignment.center,
                    child: Icon(game.platform.icon, size: 26, color: Colors.white24),
                  )
                : CachedNetworkImage(imageUrl: game.headerImageUrl, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _DownTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _UpTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
