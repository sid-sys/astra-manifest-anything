import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/admin_service.dart' show AdminService;
import '../theme/astra_theme.dart';
import '../widgets/aura_background.dart';
import 'admin_config.dart';
import 'admin_models.dart';
import 'admin_repository.dart';
import 'user_detail_screen.dart';
import 'widgets/admin_widgets.dart';

/// One piece of feedback, a bug report or a content report.
class AdminFeedbackItem {
  const AdminFeedbackItem({
    required this.id,
    required this.source,
    required this.uid,
    required this.kind,
    required this.text,
    required this.createdAt,
    required this.handled,
  });

  factory AdminFeedbackItem.fromMap(Map<String, dynamic> map) => AdminFeedbackItem(
    id: map['id'] as String? ?? '',
    source: map['source'] as String? ?? 'feedback',
    uid: map['uid'] as String?,
    kind: map['kind'] as String? ?? 'feedback',
    text: map['text'] as String? ?? '',
    createdAt: DateTime.tryParse(map['createdAt'] as String? ?? ''),
    handled: map['handled'] == true,
  );

  final String id;

  /// `feedback` or `reports`: which collection it lives in.
  final String source;
  final String? uid;

  /// `feedback`, `bug` or `report`.
  final String kind;
  final String text;
  final DateTime? createdAt;
  final bool handled;
}

final adminFeedbackProvider = FutureProvider.autoDispose<List<AdminFeedbackItem>>((
  ref,
) async {
  final rows = await AdminService().feedback();
  return rows.map(AdminFeedbackItem.fromMap).toList();
});

/// Feedback and bug reports, with a tick for the ones that are handled.
class AdminFeedbackScreen extends ConsumerStatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  ConsumerState<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends ConsumerState<AdminFeedbackScreen> {
  String? _working;

  Future<void> _toggle(AdminFeedbackItem item) async {
    setState(() => _working = item.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AdminService().setFeedbackHandled(
        source: item.source,
        id: item.id,
        handled: !item.handled,
      );
      ref.invalidate(adminFeedbackProvider);
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  AdminUser? _who(String? uid) {
    final users = ref.read(adminDataProvider).valueOrNull?.users ?? const [];
    for (final user in users) {
      if (user.id == uid) return user;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(adminFeedbackProvider);

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Column(
            children: [
              AdminBar(
                title: 'Feedback and bugs',
                actions: [
                  AdminIconButton(
                    icon: Icons.refresh_rounded,
                    label: 'Refresh',
                    onTap: () => ref.invalidate(adminFeedbackProvider),
                  ),
                ],
              ),
              Expanded(
                child: items.when(
                  loading: () => const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (error, _) => EmptyNote('Could not load feedback.\n$error'),
                  data: (list) => list.isEmpty
                      ? const EmptyNote('No feedback or bug reports yet.')
                      : ListView.separated(
                          padding: adminPadding.copyWith(bottom: 32, top: 4),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final item = list[i];
                            final who = _who(item.uid);
                            return AdminCard(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                    button: true,
                                    label: item.handled ? 'Mark not handled' : 'Mark handled',
                                    child: InkWell(
                                      onTap: _working == null ? () => _toggle(item) : null,
                                      customBorder: const CircleBorder(),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: _working == item.id
                                            ? const SizedBox(
                                                width: 24,
                                                height: 24,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : Icon(
                                                item.handled
                                                    ? Icons.check_circle_rounded
                                                    : Icons.radio_button_unchecked_rounded,
                                                size: 26,
                                                color: item.handled
                                                    ? AdminColors.good
                                                    : AstraColors.line,
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            TagPill(
                                              switch (item.kind) {
                                                'bug' => 'Bug',
                                                'report' => 'Content report',
                                                _ => 'Feedback',
                                              },
                                              color: item.kind == 'bug'
                                                  ? AdminColors.bad
                                                  : AdminColors.link,
                                            ),
                                            if (item.createdAt != null)
                                              Text(
                                                '${shortDate(item.createdAt!)}, ${timeOfDay(item.createdAt!)}',
                                                style: AstraTextStyles.small,
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.text.isEmpty ? '(no text)' : item.text,
                                          style: AstraTextStyles.body.copyWith(
                                            color: item.handled ? AdminColors.dim : null,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: who == null
                                              ? null
                                              : () => Navigator.of(context).push(
                                                  MaterialPageRoute<void>(
                                                    builder: (_) =>
                                                        AdminUserDetailScreen(user: who),
                                                  ),
                                                ),
                                          child: Text(
                                            who == null
                                                ? 'From an account that is not in the list'
                                                : 'From ${who.displayName}',
                                            style: AstraTextStyles.small.copyWith(
                                              color: who == null ? null : AdminColors.link,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
