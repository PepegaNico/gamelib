import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'updates_state.dart';

class UpdatesBell extends StatelessWidget {
  const UpdatesBell({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<UpdatesState>().unreadCount;

    return IconButton(
      tooltip: 'Updates',
      onPressed: () =>
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const UpdatesScreen())),
      icon: Badge(
        label: Text('$unread'),
        isLabelVisible: unread > 0,
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<UpdatesState>().markAllRead(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<UpdatesState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Updates & Patchnotes')),
      body: state.isLoading && state.recentItems.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.recentItems.isEmpty
          ? const Center(
              child: Text(
                'Keine aktuellen Neuigkeiten in den letzten 30 Tagen.',
              ),
            )
          : ListView.separated(
              itemCount: state.recentItems.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = state.recentItems[index];
                return ListTile(
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.gameName,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.contents,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(item.date),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(
                    Uri.parse(item.url),
                    mode: LaunchMode.externalApplication,
                  ),
                );
              },
            ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}
