import 'package:flutter/material.dart';

import '../theme/astra_theme.dart';
import '../widgets/aura_background.dart';
import 'admin_config.dart';
import 'admin_models.dart';
import 'admin_stats.dart';
import 'user_detail_screen.dart';
import 'widgets/admin_widgets.dart';

enum _Filter { all, subscribed, free, activeToday }

enum _Sort { signedUp, lastSeen, installed, uninstalled }

/// A list of real people: all of them, or the ones behind a card or a bar.
///
/// With [full] it has the filter chips and the sort order; without, it is a
/// plain list in the order given, with a search box.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({
    super.key,
    required this.title,
    required this.entries,
    this.emptyText = 'Nobody here yet.',
    this.full = false,
    this.reasons = const {},
  });

  final String title;
  final List<PersonEntry> entries;
  final String emptyText;
  final bool full;

  /// For the hidden-accounts list: why each account (by id) is left out.
  final Map<String, String> reasons;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  _Sort _sort = _Sort.signedUp;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _keep(AdminUser user, String today) {
    final matchesFilter = switch (_filter) {
      _Filter.all => true,
      _Filter.subscribed => user.subscribed,
      _Filter.free => !user.subscribed,
      _Filter.activeToday => user.wasActiveOn(today),
    };
    if (!matchesFilter) return false;

    final query = _search.text.trim().toLowerCase();
    return query.isEmpty ||
        user.displayName.toLowerCase().contains(query) ||
        user.email.toLowerCase().contains(query);
  }

  int _compare(PersonEntry a, PersonEntry b) {
    int later(DateTime? x, DateTime? y) {
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    }

    return switch (_sort) {
      _Sort.signedUp => b.user.joinedAt.compareTo(a.user.joinedAt),
      _Sort.lastSeen => b.user.lastSeen.compareTo(a.user.lastSeen),
      _Sort.installed => later(a.user.installedAt, b.user.installedAt),
      _Sort.uninstalled => later(a.user.uninstalledAt, b.user.uninstalledAt),
    };
  }

  @override
  Widget build(BuildContext context) {
    final today = utcDayKey(DateTime.now());
    var shown = widget.entries.where((e) => _keep(e.user, today)).toList();
    if (widget.full) shown = [...shown]..sort(_compare);

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Column(
            children: [
              AdminBar(title: widget.title),
              Padding(
                padding: adminPadding,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: AstraTextStyles.body,
                  cursorColor: AdminColors.highlight,
                  decoration: InputDecoration(
                    hintText: 'Search name or email',
                    hintStyle: AstraTextStyles.bodyDim,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: AstraColors.canvas,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: AstraColors.line),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: AstraColors.line),
                    ),
                  ),
                ),
              ),
              if (widget.full) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: adminPadding,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final (filter, label) in const [
                          (_Filter.all, 'All'),
                          (_Filter.subscribed, 'Subscribed'),
                          (_Filter.free, 'Free'),
                          (_Filter.activeToday, 'Active today'),
                        ])
                          AdminChip(
                            label: label,
                            selected: _filter == filter,
                            onTap: () => setState(() => _filter = filter),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: adminPadding,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Sort', style: AstraTextStyles.small),
                        for (final (sort, label) in const [
                          (_Sort.signedUp, 'Signed up'),
                          (_Sort.lastSeen, 'Last seen'),
                          (_Sort.installed, 'Installed'),
                          (_Sort.uninstalled, 'Uninstalled'),
                        ])
                          AdminChip(
                            label: label,
                            selected: _sort == sort,
                            onTap: () => setState(() => _sort = sort),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: shown.isEmpty
                    ? EmptyNote(
                        widget.entries.isEmpty ? widget.emptyText : 'Nobody matches.',
                      )
                    : ListView.separated(
                        padding: adminPadding.copyWith(bottom: 32),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => PersonRow(
                          entry: shown[i],
                          reason: widget.reasons[shown[i].user.id],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => AdminUserDetailScreen(user: shown[i].user),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
