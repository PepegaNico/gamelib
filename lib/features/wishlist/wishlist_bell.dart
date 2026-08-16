import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'wishlist_screen.dart';
import 'wishlist_state.dart';

class WishlistBell extends StatelessWidget {
  const WishlistBell({super.key});

  @override
  Widget build(BuildContext context) {
    final alerted = context.watch<WishlistState>().alertedEntries.length;

    return IconButton(
      tooltip: 'Wishlist & Preisalarm',
      onPressed: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const WishlistScreen())),
      icon: Badge(
        label: Text('$alerted'),
        isLabelVisible: alerted > 0,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.favorite_border),
      ),
    );
  }
}
