import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/plan.dart';
import '../providers.dart';
import '../services/admin_service.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';
import 'broadcast_screen.dart';

/// Who signed up, when they were last here, and how much they have written.
///
/// Everything on this screen comes from one call to `adminOverview`, which
/// refuses anyone who is not signed in with the admin Google account. Nothing
/// is computed here and nothing is cached: the numbers are whatever the server
/// said when the screen was opened, and pull-to-refresh asks again.
class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  late Future<AdminOverview> _overview;

  /// The account currently having its entitlement changed, so one card can
  /// show a spinner without the rest of the list going inert.
  String? _working;

  @override
  void initState() {
    super.initState();
    _overview = ref.read(adminServiceProvider).overview();
  }

  Future<void> _refresh() async {
    final next = ref.read(adminServiceProvider).overview();

    // Braces, not an arrow. `=> _overview = next` *returns* the assigned
    // value, and the assigned value here is a Future — which setState refuses
    // outright, so every refresh threw. It was invisible until a refresh had a
    // reason to happen: nothing on this screen refreshed itself before
    // closing an account did.
    setState(() {
      _overview = next;
    });

    try {
      await next;
    } catch (error) {
      // Swallowed rather than rethrown: the builder below already renders the
      // failure, and letting it escape here leaves the refresh spinner turning
      // over a screen that has finished.
      debugPrint('Maya: admin overview refresh failed — $error');
    }
  }

  /// Grants or removes a test entitlement, then re-reads the list so the card
  /// shows what the server actually holds rather than what was asked for.
  Future<void> _setTrial(AdminUser user, int days) async {
    final sure = days == 0
        ? await _confirmRevoke(user)
        : await _confirmGrant(user, days);
    if (!sure) return;
    if (!mounted) return;

    setState(() => _working = user.uid);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(adminServiceProvider).setTrial(uid: user.uid, days: days);
      await _refresh();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            days == 0
                ? 'Plus removed from ${user.email ?? user.uid}.'
                : '$days-day test trial on ${user.email ?? user.uid}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  /// Strips the old onboarding fields from every account, after asking.
  Future<void> _cleanOld() async {
    final sure = await confirmDelete(
      context,
      'Remove old onboarding fields from every account?',
    );
    if (!sure || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await ref.read(adminServiceProvider).cleanOldFields();
      messenger.showSnackBar(SnackBar(content: Text('Cleaned $count accounts.')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  /// Closes an account, after asking twice-over in plain words.
  ///
  /// The confirmation spells out the two things that are easy to get wrong
  /// about this: that it cannot be undone from here, and that the person can
  /// sign up again with the same address — as somebody new, with none of their
  /// writing.
  Future<void> _deleteAccount(AdminUser user) async {
    if (!await _confirmDelete(user)) return;
    if (!mounted) return;

    setState(() => _working = user.uid);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final purgeAfter = await ref
          .read(adminServiceProvider)
          .deleteAccount(user.uid);
      await _refresh();
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            purgeAfter == null
                ? '${user.email ?? user.uid} closed.'
                : '${user.email ?? user.uid} closed. Data is destroyed on '
                      '${_UserCard._date(purgeAfter)}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<bool> _confirmDelete(AdminUser user) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AstraColors.canvasRaised,
          title: Text('Close this account?', style: AstraTextStyles.display(20)),
          content: Text(
            '${user.email ?? user.uid} will be signed out and cannot sign in '
            'again. They can sign up with the same email, but it starts a new '
            'account — none of their manifestations come back.\n\n'
            'Their data is kept for 7 days, then destroyed. This cannot be '
            'undone from here.',
            style: AstraTextStyles.bodyDim,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: AstraTextStyles.small),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Close account',
                style: AstraTextStyles.small.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ) ??
      false;

  /// Asked before granting or extending a test trial — a stray tap here
  /// silently gives an account Plus, which nothing else on this row warns
  /// about.
  Future<bool> _confirmGrant(AdminUser user, int days) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AstraColors.canvasRaised,
          title: Text(
            user.subscribed ? 'Extend Plus?' : 'Grant Plus?',
            style: AstraTextStyles.display(20),
          ),
          content: Text(
            user.subscribed
                ? 'Adds $days days of Plus to ${user.email ?? user.uid}, on '
                      'top of what they already have.'
                : 'Gives ${user.email ?? user.uid} $days days of Plus for '
                      'free, marked as a test grant. Google is not billed.',
            style: AstraTextStyles.bodyDim,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: AstraTextStyles.small),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                user.subscribed ? 'Extend' : 'Grant',
                style: AstraTextStyles.small.copyWith(
                  color: AstraColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ) ??
      false;

  /// Asked before taking Plus away, because this screen cannot tell a test
  /// grant from a real subscription — both are the same document — and
  /// revoking someone who actually paid locks them out until Play is verified
  /// again on their device.
  Future<bool> _confirmRevoke(AdminUser user) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AstraColors.canvasRaised,
          title: Text('Remove Plus?', style: AstraTextStyles.display(20)),
          content: Text(
            'This takes Plus off ${user.email ?? user.uid} straight away. If '
            'they paid Google for it, they lose access until their device '
            'verifies the purchase again.',
            style: AstraTextStyles.bodyDim,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: AstraTextStyles.small),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Remove',
                style: AstraTextStyles.small.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuraBackground(
      child: SafeArea(
        child: FutureBuilder<AdminOverview>(
          future: _overview,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (snapshot.hasError) {
              return _Failed(
                error: snapshot.error!,
                onRetry: _refresh,
                onBack: () => Navigator.of(context).pop(),
              );
            }

            return _Overview(
              overview: snapshot.data!,
              onRefresh: _refresh,
              working: _working,
              onSetTrial: _setTrial,
              onDelete: _deleteAccount,
              onCleanOld: _cleanOld,
            );
          },
        ),
      ),
    ),
  );
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.overview,
    required this.onRefresh,
    required this.working,
    required this.onSetTrial,
    required this.onDelete,
    required this.onCleanOld,
  });

  final VoidCallback onCleanOld;
  final AdminOverview overview;
  final Future<void> Function() onRefresh;

  /// The uid mid-change, or null.
  final String? working;

  /// Days of Plus to put on an account. Zero takes it off.
  final void Function(AdminUser user, int days) onSetTrial;

  /// Closes an account. Confirmed on the way in.
  final void Function(AdminUser user) onDelete;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    color: AstraColors.text,
    backgroundColor: AstraColors.canvasRaised,
    child: ListView(
      padding: AstraSpacing.screenPadding,
      children: [
        const SizedBox(height: AstraSpacing.sm),
        Row(
          children: [
            _Back(onTap: () => Navigator.of(context).pop()),
            const SizedBox(width: AstraSpacing.md),
            Text('Maya', style: AstraTextStyles.wordmark),
          ],
        ),
        const SizedBox(height: AstraSpacing.xl),
        Text('ADMIN', style: AstraTextStyles.eyebrow),
        const SizedBox(height: AstraSpacing.xs),
        Text('Everyone on Maya', style: AstraTextStyles.display(26)),
        const SizedBox(height: AstraSpacing.xl),

        // The one control that reaches every user at once, behind its own
        // screen rather than a button in the middle of this list.
        AstraGhostButton(
          label: '📣  Send an announcement',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const BroadcastScreen()),
          ),
        ),
        const SizedBox(height: AstraSpacing.sm),
        AstraGhostButton(
          label: '🧹  Remove old onboarding fields',
          onPressed: onCleanOld,
        ),
        const SizedBox(height: AstraSpacing.lg),

        Row(
          children: [
            _Stat(label: 'Users', value: '${overview.totalUsers}'),
            const SizedBox(width: AstraSpacing.sm),
            _Stat(label: 'Manifests', value: '${overview.totalStories}'),
            const SizedBox(width: AstraSpacing.sm),
            _Stat(label: 'Affirms', value: '${overview.totalAffirmations}'),
            const SizedBox(width: AstraSpacing.sm),
            _Stat(label: 'On Plus', value: '${overview.subscribers}'),
          ],
        ),
        const SizedBox(height: AstraSpacing.xl),

        if (overview.users.isEmpty)
          Text('Nobody has signed up yet.', style: AstraTextStyles.bodyDim)
        else
          for (final user in overview.users) ...[
            _UserCard(
              user: user,
              busy: working == user.uid,
              onSetTrial: working == null
                  ? (days) => onSetTrial(user, days)
                  : null,
              onDelete: working == null ? () => onDelete(user) : null,
            ),
            const SizedBox(height: AstraSpacing.sm),
          ],

        // Shown only when there are any. A grace period nobody can see is one
        // nobody uses, and this week is the only room there is to undo a
        // deletion — so it is on the same screen as the button that starts it.
        if (overview.deleted.isNotEmpty) ...[
          const SizedBox(height: AstraSpacing.xl),
          Text('CLOSED, NOT YET DESTROYED', style: AstraTextStyles.eyebrow),
          const SizedBox(height: AstraSpacing.sm),
          for (final account in overview.deleted) ...[
            _DeletedCard(account: account),
            const SizedBox(height: AstraSpacing.sm),
          ],
        ],

        const SizedBox(height: AstraSpacing.xl),
        Text(
          'Story counts are lifetime, from the server’s own counter — deleting '
          'a story does not reduce them. Granting Plus writes the same '
          'entitlement a purchase writes, marked as a grant — it is for '
          'testing, and Google is not billed for it.\n\n'
          'Closing an account signs the person out and frees their email, so '
          'they can sign up again as somebody new. What they wrote is kept for '
          '7 days and then destroyed. Undoing it inside that week is a job for '
          'the Firebase console — there is deliberately no restore button next '
          'to a delete one.\n\n'
          'Pull down to refresh.',
          style: AstraTextStyles.small,
        ),
        const SizedBox(height: AstraSpacing.xxl),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: AstraCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AstraTextStyles.display(24)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: AstraTextStyles.eyebrow),
        ],
      ),
    ),
  );
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.busy,
    required this.onSetTrial,
    required this.onDelete,
  });

  final AdminUser user;
  final bool busy;

  /// Null while another card is mid-change, which disables the controls
  /// everywhere rather than letting two grants race the same refresh.
  final void Function(int days)? onSetTrial;

  /// Closes the account. Null under the same rule as [onSetTrial].
  final VoidCallback? onDelete;

  /// "3 days ago" beats a date here: the question this screen answers is
  /// whether somebody is still around, and that is a duration, not a timestamp.
  static String _ago(DateTime? when) {
    if (when == null) return 'never';

    final gap = DateTime.now().difference(when);
    if (gap.inMinutes < 1) return 'just now';
    if (gap.inMinutes < 60) return '${gap.inMinutes}m ago';
    if (gap.inHours < 24) return '${gap.inHours}h ago';
    if (gap.inDays < 30) return '${gap.inDays}d ago';
    return '${(gap.inDays / 30).floor()}mo ago';
  }

  static String _date(DateTime? when) {
    if (when == null) return 'unknown';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = when.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  /// Short, readable provider names. `providerData` gives reverse-DNS ids.
  static String _providers(List<String> providers) {
    final names = providers
        .map(
          (provider) => switch (provider) {
            'google.com' => 'Google',
            'password' => 'Email',
            'apple.com' => 'Apple',
            _ => provider,
          },
        )
        .toSet();

    return names.isEmpty ? 'unknown' : names.join(' + ');
  }

  @override
  Widget build(BuildContext context) => AstraCard(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name ?? user.email ?? user.uid,
                    style: AstraTextStyles.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.name != null && user.email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email!,
                      style: AstraTextStyles.small,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AstraSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${user.manifests}', style: AstraTextStyles.display(20)),
                Text('MANIFESTS', style: AstraTextStyles.eyebrow),
                const SizedBox(height: 4),
                Text('${user.affirmations}', style: AstraTextStyles.display(20)),
                Text('AFFIRMS', style: AstraTextStyles.eyebrow),
              ],
            ),
          ],
        ),
        const SizedBox(height: AstraSpacing.sm),

        // The furthest step reached, given its own line above the rest. It is
        // the one fact on this card that says whether anything is wrong.
        Text(user.stage.label, style: AstraTextStyles.bodyDim),

        if (user.wishes.isNotEmpty) ...[
          const SizedBox(height: AstraSpacing.xs),
          Text('MANIFESTATIONS TYPED', style: AstraTextStyles.eyebrow),
          for (final wish in user.wishes) ...[
            const SizedBox(height: 2),
            Text('“${wish.dream}”', style: AstraTextStyles.small),
          ],
        ] else if (user.wish != null) ...[
          const SizedBox(height: AstraSpacing.xs),
          Text('Wish: “${user.wish}”', style: AstraTextStyles.small),
        ],
        const SizedBox(height: AstraSpacing.xs),
        Text(
          'Opened ${user.appOpens}× · price seen ${user.paywallViews}× · '
          'subscribe pressed ${user.subscribeTaps}× · '
          'backed out ${user.purchaseCancels}× · errors ${user.purchaseFails}'
          '${user.trialShown == null ? '' : user.trialShown! ? ' · trial shown' : ' · trial NOT shown'}',
          style: AstraTextStyles.small,
        ),
        if (user.lastError != null && user.lastError!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            'Last error: ${user.lastError}',
            style: AstraTextStyles.small.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],

        // Where somebody stopped inside onboarding used to be shown here. It
        // is gone with onboarding itself: the only accounts that still carry
        // that field stopped inside a flow the app no longer has, so the card
        // was reporting "reached question 3 of 12" about twelve questions
        // nobody is ever asked again.

        const SizedBox(height: AstraSpacing.md),
        Wrap(
          spacing: AstraSpacing.sm,
          runSpacing: AstraSpacing.xs,
          children: [
            _Fact('Joined ${_date(user.signedUpAt)}'),
            _Fact('Seen ${_ago(user.lastSeenAt)}'),
            _Fact(_providers(user.providers)),
            if (user.storiesThisMonth > 0)
              _Fact('${user.storiesThisMonth} this month'),
            if (user.subscribed) const _Fact('Plus', strong: true),
          ],
        ),

        const SizedBox(height: AstraSpacing.xs),
        Row(
          children: [
            if (busy)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else ...[
              TextButton(
                onPressed: onSetTrial == null
                    ? null
                    : () => onSetTrial!(PricingCatalog.trialDays),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  user.subscribed
                      ? 'Extend ${PricingCatalog.trialDays} days'
                      : 'Grant ${PricingCatalog.trialDays}-day trial',
                  style: AstraTextStyles.small.copyWith(
                    color: AstraColors.accent,
                  ),
                ),
              ),
              if (user.subscribed)
                TextButton(
                  onPressed: onSetTrial == null ? null : () => onSetTrial!(0),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Remove Plus',
                    style: AstraTextStyles.small.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),

              // Pushed to the far end, away from the two buttons next to it.
              // The others are reversible in a tap; this one destroys an
              // account, and it should not sit where a thumb lands by accident.
              const Spacer(),
              TextButton(
                onPressed: onDelete,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Close account',
                  style: AstraTextStyles.small.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

/// One account closed and waiting out its week.
class _DeletedCard extends StatelessWidget {
  const _DeletedCard({required this.account});

  final DeletedAccount account;

  @override
  Widget build(BuildContext context) => AstraCard(
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.email ?? account.name ?? account.uid,
                style: AstraTextStyles.label.copyWith(fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text(
                account.purgeAfter == null
                    ? 'Closed. Waiting to be destroyed.'
                    : 'Destroyed on ${_UserCard._date(account.purgeAfter)}',
                style: AstraTextStyles.small,
              ),
            ],
          ),
        ),
        Text(
          account.daysLeft == 0
              ? 'due'
              : '${account.daysLeft}d',
          style: AstraTextStyles.small.copyWith(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      ],
    ),
  );
}

class _Fact extends StatelessWidget {
  const _Fact(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: strong ? AstraColors.accentWash : AstraColors.canvas,
      borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
      border: Border.all(color: AstraColors.line),
    ),
    child: Text(
      text,
      style: AstraTextStyles.small.copyWith(
        color: strong ? AstraColors.text : AstraColors.dim,
        fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
      ),
    ),
  );
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.error,
    required this.onRetry,
    required this.onBack,
  });

  final Object error;
  final Future<void> Function() onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: AstraSpacing.screenPadding,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Could not load', style: AstraTextStyles.display(24)),
        const SizedBox(height: AstraSpacing.sm),
        Text(
          // The server says "Not available." to anyone it refuses, on purpose,
          // so this shows whatever came back rather than guessing at a cause.
          '$error',
          style: AstraTextStyles.bodyDim,
        ),
        const SizedBox(height: AstraSpacing.xl),
        AstraButton(label: 'Try again', onPressed: onRetry),
        const SizedBox(height: AstraSpacing.sm),
        AstraGhostButton(label: 'Back', onPressed: onBack),
      ],
    ),
  );
}

class _Back extends StatelessWidget {
  const _Back({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Back',
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AstraColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AstraColors.line),
        ),
        child: Icon(
          Icons.arrow_back_rounded,
          size: 18,
          color: AstraColors.text,
        ),
      ),
    ),
  );
}
