import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/intention.dart';
import '../providers.dart';
import '../services/auth_service.dart';
import '../theme/astra_theme.dart';
import '../widgets/allowance_ring.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/profile_avatar.dart';
import 'auth_screen.dart';
import 'confirm_screen.dart';
import 'paywall_screen.dart';
import 'player_screen.dart';

/// Profile, settings, the monthly practice meter, and everything kept.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final favouriteStories = ref.watch(favouriteStoriesProvider);
    final keptLines = ref.watch(tasteProvider).liked.toList();
    final practised = ref.watch(daysPractisedThisMonthProvider);
    final usage = ref.watch(usageProvider);
    final minutes = ref.watch(minutesInLibraryProvider);
    final daysInMonth = DateUtils.getDaysInMonth(
      DateTime.now().year,
      DateTime.now().month,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        const Wordmark('Profile'),
        const SizedBox(height: AstraSpacing.xl),
        Center(
          child: Column(
            children: [
              // The photo is edited here now, which is the only place anyone
              // would look for it. Home used to carry a tappable avatar in the
              // middle of the screen, where a camera badge sat next to the
              // question and competed with it.
              ProfileAvatar(name: profile.name, size: 88),
              const SizedBox(height: AstraSpacing.md),
              Text(profile.name, style: AstraTextStyles.label.copyWith(fontSize: 16)),
              Text(
                'Manifesting since ${DateFormat('MMMM yyyy').format(profile.joinedAt)}',
                style: AstraTextStyles.small,
              ),
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.xl),

        _SettingRow(
          label: 'Intentions & life details',
          value: profile.intentions.map((i) => i.label).join(', '),
          onTap: () => editIntentions(context, ref),
        ),
        // The same ring as Home, for the same reason: the number of stories
        // left is the one fact about the plan that changes, and it should read
        // identically wherever it is shown.
        AllowanceCard(
          usage: usage,
          onTap: profile.isSubscribed
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => const PaywallScreen(),
                    ),
                  ),
        ),
        const SizedBox(height: AstraSpacing.md),

        AstraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This month', style: AstraTextStyles.small),
              const SizedBox(height: AstraSpacing.sm),
              AstraProgressBar(value: practised / daysInMonth),
              const SizedBox(height: AstraSpacing.sm),
              Text(
                '$practised of $daysInMonth days practised · '
                '$minutes minutes in your library',
                style: AstraTextStyles.small,
              ),
            ],
          ),
        ),

        const SizedBox(height: AstraSpacing.xl),
        Text('Saved stories', style: AstraTextStyles.label),
        const SizedBox(height: AstraSpacing.sm),
        if (favouriteStories.isEmpty)
          Text(
            'Nothing saved yet. Tap the heart on a story to keep it here.',
            style: AstraTextStyles.small,
          )
        else
          for (final story in favouriteStories) ...[
            AstraCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              onTap: () {
                ref.read(playbackProvider).load(story);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const PlayerScreen()),
                );
              },
              child: Row(
                children: [
                  Text(
                    story.intention.glyph,
                    style: TextStyle(fontSize: 16, color: story.intention.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          story.title,
                          style: AstraTextStyles.body.copyWith(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${story.durationLabel} · ${story.hasAudio ? 'audio and text' : 'text'}',
                          style: AstraTextStyles.small,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    color: AstraColors.accent,
                    size: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AstraSpacing.sm),
          ],

        const SizedBox(height: AstraSpacing.lg),
        Text('Kept affirmations', style: AstraTextStyles.label),
        const SizedBox(height: AstraSpacing.sm),
        if (keptLines.isEmpty)
          Text(
            'Swipe right on an affirmation and it lands here.',
            style: AstraTextStyles.small,
          )
        else
          for (final line in keptLines) ...[
            AstraCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '“$line”',
                      style: AstraTextStyles.quote.copyWith(fontSize: 14),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.favorite,
                      size: 17,
                      color: AstraColors.accent,
                    ),
                    tooltip: 'Remove',
                    onPressed: () =>
                        ref.read(tasteProvider.notifier).unlike(line),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AstraSpacing.sm),
          ],

        // Last on the screen, below everything worth keeping — the two actions
        // nobody should reach by scrolling absent-mindedly.
        const SizedBox(height: AstraSpacing.xxl),
        Text('Account', style: AstraTextStyles.label),
        const SizedBox(height: AstraSpacing.sm),

        if (ref.watch(isGuestProvider)) ...[
          // Offered, never enforced. A guest account is a full account; this
          // is about not losing it with the phone.
          _AccountRow(
            icon: Icons.mark_email_read_outlined,
            label: 'Add an email',
            detail: 'Keeps your stories if you change phones',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) => const AuthScreen(asUpgrade: true),
              ),
            ),
          ),
          const SizedBox(height: AstraSpacing.sm),
        ] else ...[
          _AccountRow(
            icon: Icons.alternate_email_rounded,
            label: ref.watch(authStateProvider).valueOrNull?.email ??
                'Signed in',
            detail: 'Send a link to change your password',
            onTap: () => _resetPassword(context, ref),
          ),
          const SizedBox(height: AstraSpacing.sm),
        ],

        _AccountRow(
          icon: Icons.logout_rounded,
          label: 'Log out',
          detail: 'Clears this device',
          onTap: () => _confirm(context, ConfirmKind.signOut),
        ),
        const SizedBox(height: AstraSpacing.sm),
        _AccountRow(
          icon: Icons.delete_outline_rounded,
          label: 'Delete my data',
          detail: 'Everything, everywhere, permanently',
          danger: true,
          onTap: () => _confirm(context, ConfirmKind.deleteData),
        ),
      ],
    );
  }

  /// Changing a password by email rather than in a form.
  ///
  /// `updatePassword` needs a recent sign-in and fails with
  /// `requires-recent-login` for anyone who has been signed in a while, which
  /// makes it a button that works on the test device and not on a real one.
  /// The email round trip also proves the address still belongs to whoever is
  /// holding the phone.
  static Future<void> _resetPassword(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authServiceProvider).sendPasswordResetForCurrentUser();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Link sent. Check your inbox, and your spam folder if it is not '
            'there in a few minutes.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(authErrorMessage(error))));
    }
  }

  static Future<void> _confirm(BuildContext context, ConfirmKind kind) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ConfirmScreen(kind: kind)),
      );

}

/// The intentions sheet.
///
/// Top-level rather than a method because two screens open it now: Profile,
/// where it reads as a setting, and Home's "Edit desires", where it is the
/// control over what the feed is made of. One sheet, so the two can never
/// drift apart.
Future<void> editIntentions(BuildContext context, WidgetRef ref) async {
  final profile = ref.read(profileProvider);
  final selected = {...profile.intentions};

  final saved = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AstraColors.canvasRaised,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Intentions', style: AstraTextStyles.display(20)),
              const SizedBox(height: AstraSpacing.md),
              Wrap(
                spacing: AstraSpacing.sm,
                runSpacing: AstraSpacing.sm,
                children: [
                  for (final intention in Intention.values)
                    TagChip(
                      label: '${intention.glyph}  ${intention.label}',
                      selected: selected.contains(intention),
                      accent: intention.accent,
                      onTap: () => setSheetState(() {
                        selected.contains(intention)
                            ? selected.remove(intention)
                            : selected.add(intention);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AstraSpacing.lg),
              AstraButton(
                label: 'Save',
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.of(sheetContext).pop(true),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  if (saved != true) return;
  await ref
      .read(profileProvider.notifier)
      .update(profile.copyWith(intentions: selected));
}

/// A row in the Account block. The destructive one is tinted, but only its
/// icon and label — a whole card in error red reads as something already
/// broken rather than something that would break.
class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tint = danger ? Theme.of(context).colorScheme.error : AstraColors.text;

    return AstraCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: AstraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AstraTextStyles.body.copyWith(color: tint),
                ),
                Text(detail, style: AstraTextStyles.small),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AstraColors.dim,
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AstraSpacing.sm),
    child: AstraCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: Text(label, style: AstraTextStyles.body)),
          Flexible(
            child: Text(
              value,
              style: AstraTextStyles.bodyDim,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, size: 18, color: AstraColors.dim),
        ],
      ),
    ),
  );
}
