import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../auth/auth_state.dart';
import '../library/backlog_picker.dart';
import '../library/library_screen.dart';
import '../library/library_state.dart';
import '../settings/settings_screen.dart';
import '../store/store_search_screen.dart';
import '../updates/updates_screen.dart';
import '../updates/updates_state.dart';
import '../wishlist/wishlist_screen.dart';
import '../wishlist/wishlist_state.dart';

enum AppSection { library, store, wishlist, updates, settings }

/// Signed-in root: persistent sidebar plus one nested Navigator per
/// section, so detail pages open inside the content area (sidebar stays)
/// and every section keeps its own scroll/back stack when switching.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Switches the sidebar section from anywhere below the shell.
  static void select(BuildContext context, AppSection section) =>
      context.findAncestorStateOfType<_AppShellState>()?._select(section);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _section = AppSection.library;

  /// Sections are built lazily on first visit — the store/wishlist screens
  /// start network work in initState that shouldn't run at app start.
  final Set<AppSection> _visited = {AppSection.library};
  final _navigatorKeys = {
    for (final s in AppSection.values) s: GlobalKey<NavigatorState>(),
  };

  /// Null until toggled, so the sidebar follows the window width.
  bool? _expanded;

  void _select(AppSection section) {
    if (section == _section) {
      // Re-selecting the active section jumps back to its start page.
      _navigatorKeys[section]!.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _section = section;
      _visited.add(section);
    });
  }

  Widget _page(AppSection section) => switch (section) {
    AppSection.library => const LibraryScreen(),
    AppSection.store => const StoreSearchScreen(),
    AppSection.wishlist => const WishlistScreen(),
    AppSection.updates => const UpdatesScreen(),
    AppSection.settings => const SettingsScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final expanded = _expanded ?? MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            expanded: expanded,
            selected: _section,
            wishlistAlerts: context
                .watch<WishlistState>()
                .alertedEntries
                .length,
            updatesUnread: context.watch<UpdatesState>().unreadCount,
            avatarUrl: auth.avatarUrl,
            personaName: auth.personaName,
            onToggle: () => setState(() => _expanded = !expanded),
            onSelect: _select,
            onBacklog: () {
              final games = context.read<LibraryState>().games;
              if (games.isNotEmpty) showBacklogPicker(context, games);
            },
            onSignOut: () => context.read<AuthState>().signOut(),
          ),
          Expanded(
            child: IndexedStack(
              index: _section.index,
              children: [
                for (final section in AppSection.values)
                  _visited.contains(section)
                      ? HeroControllerScope.none(
                          child: Navigator(
                            key: _navigatorKeys[section],
                            onGenerateRoute: (_) => MaterialPageRoute(
                              builder: (_) => _page(section),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Slim desktop sidebar. Collapses to icons only on narrow windows (or
/// when toggled).
class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.expanded,
    required this.selected,
    required this.wishlistAlerts,
    required this.updatesUnread,
    required this.avatarUrl,
    required this.personaName,
    required this.onToggle,
    required this.onSelect,
    required this.onBacklog,
    required this.onSignOut,
  });

  final bool expanded;
  final AppSection selected;
  final int wishlistAlerts;
  final int updatesUnread;
  final String? avatarUrl;
  final String? personaName;
  final VoidCallback onToggle;
  final ValueChanged<AppSection> onSelect;
  final VoidCallback onBacklog;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    Widget item(
      AppSection? section,
      IconData icon,
      String label, {
      int badge = 0,
      VoidCallback? onTap,
    }) => _SidebarItem(
      icon: icon,
      label: label,
      expanded: expanded,
      selected: section != null && selected == section,
      badge: badge,
      onTap: onTap ?? () => onSelect(section!),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: expanded ? 212 : 68,
      decoration: const BoxDecoration(
        color: Color(0xFF09090C),
        border: Border(right: BorderSide(color: zerDivider)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: expanded ? Alignment.centerLeft : Alignment.center,
            child: IconButton(
              tooltip: expanded ? 'Menü einklappen' : 'Menü ausklappen',
              onPressed: onToggle,
              icon: Icon(
                expanded ? Icons.menu_open_rounded : Icons.menu_rounded,
                color: zerTextSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          item(AppSection.library, Icons.grid_view_rounded, 'Bibliothek'),
          item(AppSection.store, Icons.storefront_outlined, 'Store'),
          item(
            AppSection.wishlist,
            Icons.favorite_border_rounded,
            'Wunschliste',
            badge: wishlistAlerts,
          ),
          item(
            AppSection.updates,
            Icons.notifications_none_rounded,
            'Updates',
            badge: updatesUnread,
          ),
          item(null, Icons.casino_outlined, 'Was spielen?', onTap: onBacklog),
          const Spacer(),
          item(AppSection.settings, Icons.settings_outlined, 'Einstellungen'),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Tooltip(
                message: personaName ?? 'Konto',
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: zerSurfaceHigh,
                  backgroundImage: (avatarUrl?.isNotEmpty ?? false)
                      ? NetworkImage(avatarUrl!)
                      : null,
                  child: (avatarUrl?.isNotEmpty ?? false)
                      ? null
                      : const Icon(Icons.person, size: 16),
                ),
              ),
              if (expanded) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    personaName ?? 'Konto',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Abmelden',
                  visualDensity: VisualDensity.compact,
                  onPressed: onSignOut,
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: zerTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? zerTextPrimary : zerTextSecondary;
    final iconWidget = Badge(
      isLabelVisible: badge > 0,
      label: Text('$badge'),
      backgroundColor: zerAccent,
      textColor: zerOnAccent,
      child: Icon(icon, size: 20, color: selected ? zerAccent : color),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tooltip(
        message: expanded ? '' : label,
        child: Material(
          color: selected
              ? zerAccent.withValues(alpha: 0.14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: SizedBox(
              height: 42,
              child: expanded
                  ? Row(
                      children: [
                        const SizedBox(width: 12),
                        iconWidget,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                            style: TextStyle(
                              color: color,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Center(child: iconWidget),
            ),
          ),
        ),
      ),
    );
  }
}
