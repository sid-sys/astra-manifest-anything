import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';
import 'admin_config.dart';
import 'admin_models.dart';
import 'admin_repository.dart';
import 'user_detail_screen.dart';
import 'widgets/admin_widgets.dart';

enum _Filter { all, subscribed, free, activeToday }

/// Everybody, searchable, with the people who did something most recently at
/// the top.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _keep(AdminUser user, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final matchesFilter = switch (_filter) {
      _Filter.all => true,
      _Filter.subscribed => user.subscribed,
      _Filter.free => !user.subscribed,
      _Filter.activeToday => user.wasActiveOn(today),
    };
    if (!matchesFilter) return false;

    final query = _search.text.trim().toLowerCase();
    return query.isEmpty ||
        user.name.toLowerCase().contains(query) ||
        user.email.toLowerCase().contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(adminUsersProvider);

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Column(
            children: [
              AdminBar(
                title: 'Users',
                actions: [if (kAdminMock) const MockTag()],
              ),
              Padding(
                padding: adminPadding,
                child: TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  style: AstraTextStyles.body,
                  cursorColor: AstraColors.accent,
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
                        TagChip(
                          label: label,
                          selected: _filter == filter,
                          onTap: () => setState(() => _filter = filter),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: users.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('$error', style: AstraTextStyles.small),
                    ),
                  ),
                  data: (all) {
                    final now = DateTime.now();
                    final shown = all.where((u) => _keep(u, now)).toList();
                    if (shown.isEmpty) {
                      return Center(
                        child: Text('Nobody matches.', style: AstraTextStyles.bodyDim),
                      );
                    }
                    return ListView.separated(
                      padding: adminPadding.copyWith(bottom: 32),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _UserRow(
                        user: shown[i],
                        now: now,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AdminUserDetailScreen(user: shown[i]),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.now, required this.onTap});

  final AdminUser user;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AstraCard(
    onTap: onTap,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(
      children: [
        AdminAvatar(initials: user.initials),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AstraTextStyles.body.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AstraTextStyles.small,
              ),
              Text(
                'Joined ${shortDate(user.joinedAt)} · Seen ${ago(user.lastSeen, now)}',
                maxLines: 2,
                style: AstraTextStyles.small,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        PlanPill(user: user),
      ],
    ),
  );
}
