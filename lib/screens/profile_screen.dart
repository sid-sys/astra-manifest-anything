import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/intention.dart';
import '../providers.dart';
import '../services/auth_service.dart';
import '../services/billing_service.dart';
import '../services/legal_links.dart';
import '../theme/astra_theme.dart';
import '../widgets/allowance_ring.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/profile_avatar.dart';
import '../admin/dashboard_screen.dart';
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
              // The name. This showed the desire sentence for as long as
              // onboarding had stopped asking for one, which read as a slogan
              // pinned to a profile rather than a person's account. Accounts
              // made in that window have no name stored, so the desire is
              // still the fallback rather than a blank line.
              Text(
                profile.name.isNotEmpty
                    ? profile.name
                    : (profile.preferences.desire.isNotEmpty
                          ? profile.preferences.desire
                          : (profile.aspiration.isNotEmpty
                                ? profile.aspiration
                                : 'Your Mayow')),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AstraTextStyles.label.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                'Manifesting since ${DateFormat('MMMM yyyy').format(profile.joinedAt)}',
                style: AstraTextStyles.small,
              ),
            ],
          ),
        ),
        const SizedBox(height: AstraSpacing.xl),

        // One row, not two. This used to be "Story preferences" and
        // "Intentions & life details" side by side, which put the same
        // underlying question — what is this account actually about — behind
        // two different settings that could disagree with each other. Life
        // areas now live inside Story preferences, reachable one tap further
        // in rather than one row over.
        // What Mayow calls you, in every story it writes.
        _SettingRow(
          label: 'Your name',
          value: profile.name.isEmpty ? 'Not set' : profile.name,
          onTap: () => _editName(context, ref),
        ),
        // Two sends, so two rows.
        //
        // The server has sent morning and night for a while — the user's own
        // time, and 10 PM unless they move it — but this screen only ever
        // showed the first one, under a label that said "Daily affirmation".
        // Somebody reading their own settings had no way to learn that a
        // second one was coming, or to move it.
        _SettingRow(
          label: 'Affirmation reminders',
          value: profile.remindersOn ? 'On' : 'Off',
          onTap: () => _toggleReminders(context, ref),
        ),
        if (profile.remindersOn) ...[
          _SettingRow(
            label: 'Morning',
            value: _formatTime(profile.reminderHour, profile.reminderMinute),
            onTap: () => _editSlot(context, ref, evening: false),
          ),
          _SettingRow(
            label: 'Night',
            value: _formatTime(profile.eveningHour, profile.eveningMinute),
            onTap: () => _editSlot(context, ref, evening: true),
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: 4,
              right: 4,
              bottom: AstraSpacing.sm,
            ),
            child: Text(
              // Said once, under both, rather than folded into each time.
              // The sender runs on a cron tick, so a reminder set for 7:00
              // lands between 7:00 and 7:15 — never earlier, sometimes that
              // much later. A bare exact time would look broken on the days
              // it drifted.
              'Each one arrives within 15 minutes of its time.',
              style: AstraTextStyles.small,
            ),
          ),
        ],
        // The same ring as Home, for the same reason: the number of stories
        // left is the one fact about the plan that changes, and it should read
        // identically wherever it is shown.
        AllowanceCard(
          usage: usage,
          onTap: ref.watch(isSubscribedProvider)
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => const PaywallScreen(),
                    ),
                  ),
        ),

        // Cancelling, and where it actually happens.
        //
        // Shown only to someone on a live plan, and it opens Play's own page
        // for this app rather than the list of every subscription they hold.
        // The app cannot cancel anything itself — Google owns the billing — so
        // the choice is between one honest tap and a paragraph telling them to
        // go and find it. A subscription that is hard to leave is one people
        // refuse to start.
        ..._cancelRow(context, ref),

        // Cancelled, and still running.
        //
        // Play keeps a cancelled subscription alive until the period the user
        // paid for runs out, and it says nothing to them in the meantime — so
        // without this the app looks identical before and after cancelling,
        // and the first sign anything changed is the day it stops working.
        // Shown only while it is cancelled: an active plan needs no notice.
        ..._cancellationNotice(ref),

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
                  const AstraIcon('ui_play', size: 32),
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
                    icon: Icon(
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

        // A guest gets a row that states the fact and does nothing, because
        // there is no password to reset and no address to send a link to.
        // The upgrade path used to live here and was removed; anyone wanting
        // an account signs out and signs up.
        if (ref.watch(isGuestProvider))
          const _AccountRow(
            icon: Icons.person_outline_rounded,
            label: 'Guest',
            detail: 'This account lives on this phone only',
          )
        else
          _AccountRow(
            icon: Icons.alternate_email_rounded,
            label:
                ref.watch(authStateProvider).valueOrNull?.email ?? 'Signed in',
            detail: 'Send a link to change your password',
            onTap: () => _resetPassword(context, ref),
          ),
        const SizedBox(height: AstraSpacing.sm),

        // Only ever drawn for the one Google account named in AdminService,
        // and drawing it is all this does — the panel's data comes from a
        // function that checks the same thing again and refuses on its own.
        if (ref.watch(isAdminProvider).valueOrNull ?? false) ...[
          _AccountRow(
            icon: Icons.insights_rounded,
            label: 'Admin',
            detail: 'Users, revenue, profit',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AdminDashboardScreen(),
              ),
            ),
          ),
          const SizedBox(height: AstraSpacing.sm),
        ],

        _AccountRow(
          icon: Icons.logout_rounded,
          label: 'Log out',
          detail: 'Clears this device',
          // Straight out, with nothing to confirm.
          //
          // It used to open the same are-you-sure screen that deleting an
          // account does, and the two are not comparable: deleting destroys
          // the stories, logging out leaves every one of them on the server
          // and hands them back at the next sign-in. Asking twice for
          // something reversible teaches people to tap past the question,
          // which is exactly the habit you do not want them to have when the
          // screen underneath it says Delete.
          //
          // Both halves, always. `signOut` only ends the Firebase session; it
          // does not touch this device. Calling it alone left the previous
          // account's name, stories and streak sitting in local storage for
          // the next person to sign in and find — which is what happened when
          // this first bypassed the confirmation screen and inherited only
          // half of what that screen did.
          onTap: () => _logOut(context, ref),
        ),
        const SizedBox(height: AstraSpacing.sm),
        _AccountRow(
          icon: Icons.delete_outline_rounded,
          label: 'Delete my data',
          detail: 'Everything, everywhere, permanently',
          danger: true,
          onTap: () => _confirm(context, ConfirmKind.deleteData),
        ),

        // Reachable from inside the app, not only from the store listing.
        // Someone who wants to know what happens to what they typed should not
        // have to leave and find the Play page to be told — and the same three
        // URLs are what Play holds on file, so what a reviewer reads and what a
        // user reads are the same page.
        const SizedBox(height: AstraSpacing.xxl),
        Text('Legal', style: AstraTextStyles.label),
        const SizedBox(height: AstraSpacing.sm),

        _AccountRow(
          icon: Icons.shield_outlined,
          label: 'Privacy policy',
          detail: 'What is collected, and what is never sold',
          onTap: () => LegalLinks.open(context, LegalLinks.privacy),
        ),
        const SizedBox(height: AstraSpacing.sm),
        _AccountRow(
          icon: Icons.description_outlined,
          label: 'Terms of use',
          detail: 'What Mayow promises, and what it does not',
          onTap: () => LegalLinks.open(context, LegalLinks.terms),
        ),
        const SizedBox(height: AstraSpacing.sm),
        // The web page, not the in-app button above it. Play requires a URL
        // that works without installing the app, for someone who has already
        // uninstalled it and still wants their data gone.
        _AccountRow(
          icon: Icons.link_off_rounded,
          label: 'Delete your account',
          detail: 'How to erase everything, including from the web',
          onTap: () => LegalLinks.open(context, LegalLinks.deleteAccount),
        ),
        const SizedBox(height: AstraSpacing.sm),
        _AccountRow(
          icon: Icons.mail_outline_rounded,
          label: 'Contact support',
          detail: LegalLinks.supportEmail,
          onTap: () => LegalLinks.open(
            context,
            'mailto:${LegalLinks.supportEmail}',
          ),
        ),
        const SizedBox(height: AstraSpacing.xl),
      ],
    );
  }

  static String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Turns both reminders on or off.
  ///
  /// Permission is asked here, at the moment the user says they want the
  /// thing — not at launch, where it is the prompt everybody denies and can
  /// never be asked for again.
  static Future<void> _toggleReminders(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final profile = ref.read(profileProvider);
    final messenger = ScaffoldMessenger.of(context);

    if (profile.remindersOn) {
      await ref
          .read(profileProvider.notifier)
          .update(profile.copyWith(remindersOn: false));
      await refreshPushRegistration(ref);
      messenger.showSnackBar(
        const SnackBar(content: Text('Affirmation reminders turned off.')),
      );
      return;
    }

    final granted = await ref
        .read(notificationServiceProvider)
        .requestPermission();

    if (!granted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Notifications are blocked for Mayow. Turn them on in your phone '
            'settings and try again.',
          ),
        ),
      );
      return;
    }

    // On at the two defaults, and the rows below say what they are. Asking for
    // two times before sending anything would be three taps to reach a setting
    // most people will never move.
    await ref
        .read(profileProvider.notifier)
        .update(profile.copyWith(remindersOn: true));
    await refreshPushRegistration(ref);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Affirmations at ${_formatTime(profile.reminderHour, profile.reminderMinute)} '
          'and ${_formatTime(profile.eveningHour, profile.eveningMinute)}.',
        ),
      ),
    );
  }

  /// Moves one of the two.
  static Future<void> _editSlot(
    BuildContext context,
    WidgetRef ref, {
    required bool evening,
  }) async {
    final profile = ref.read(profileProvider);

    final picked = await showTimePicker(
      context: context,
      initialTime: evening
          ? TimeOfDay(hour: profile.eveningHour, minute: profile.eveningMinute)
          : TimeOfDay(hour: profile.reminderHour, minute: profile.reminderMinute),
      helpText: evening ? 'Night affirmation' : 'Morning affirmation',
    );
    if (picked == null) return;

    await ref
        .read(profileProvider.notifier)
        .update(
          evening
              ? profile.copyWith(
                  eveningHour: picked.hour,
                  eveningMinute: picked.minute,
                )
              : profile.copyWith(
                  reminderHour: picked.hour,
                  reminderMinute: picked.minute,
                ),
        );
    await refreshPushRegistration(ref);
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

  /// The "cancel my plan" row, for people who have something to cancel.
  static List<Widget> _cancelRow(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(entitlementDetailsProvider).valueOrNull;
    if (plan == null || !plan.isSubscribed || plan.isCancelled) return const [];

    return [
      const SizedBox(height: AstraSpacing.md),
      _AccountRow(
        icon: Icons.open_in_new_rounded,
        label: 'Cancel Mayow Plus',
        detail: 'Opens Google Play · you keep Plus until the period ends',
        onTap: () => LegalLinks.open(
          context,
          LegalLinks.playSubscription(
            BillingService.monthlyId,
            'com.astraapp.astra',
          ),
        ),
      ),
    ];
  }

  /// Renames the account.
  ///
  /// The name is not decoration: it is spoken in every story, so getting it
  /// wrong at signup meant hearing the wrong name read aloud for as long as the
  /// account lived. It was asked once during onboarding and never editable
  /// after.
  static Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(profileProvider);

    final name = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: profile.name),
    );

    final trimmed = name?.trim() ?? '';
    // An empty name is read aloud as a gap. Keeping the old one is the better
    // failure.
    if (trimmed.isEmpty || trimmed == profile.name) return;

    await ref.read(profileProvider.notifier).update(
      profile.copyWith(name: trimmed),
    );
  }

  /// Ends the session and erases this device's copy, in that order.
  ///
  /// The two belong together and must never be separated again: signing out
  /// without the wipe hands the next account the last one's data, and wiping
  /// without the sign-out deletes a live user's library under them.
  static Future<void> _logOut(BuildContext context, WidgetRef ref) async {
    // Taken before the sign-out — see [forgetEverythingLocal].
    final container = ProviderScope.containerOf(context);
    await container.read(accountServiceProvider).signOut();
    await forgetEverythingLocal(container);
  }

  /// The "you cancelled, it ends on X" line, or nothing at all.
  static List<Widget> _cancellationNotice(WidgetRef ref) {
    final entitlement = ref.watch(entitlementDetailsProvider).valueOrNull;
    if (entitlement == null || !entitlement.isCancelled) return const [];

    final ends = entitlement.expiryTime;

    return [
      const SizedBox(height: AstraSpacing.md),
      AstraCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AstraColors.dim,
            ),
            const SizedBox(width: AstraSpacing.sm),
            Expanded(
              child: Text(
                ends == null
                    // Play told us it is cancelled but not when it lapses.
                    // Better to say the true half than to invent a date the
                    // user will hold us to.
                    ? 'You have cancelled Mayow Plus. It stays on until the '
                        'period you have paid for ends.'
                    : 'You have cancelled Mayow Plus. It stays on until '
                        '${_longDate(ends)}, and you keep everything you '
                        'have already made.',
                style: AstraTextStyles.bodyDim,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// "3 October 2026" — spelled out, because a cancellation date read wrong is
  /// a support email, and 3/10 means two different days either side of the
  /// Atlantic.
  static String _longDate(DateTime when) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final local = when.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
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
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String detail;

  /// Null for a row that only states a fact. The chevron goes with it, so a
  /// row that does nothing does not look like a row that leads somewhere.
  final VoidCallback? onTap;
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
          if (onTap != null)
            Icon(
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
            Icon(Icons.chevron_right, size: 18, color: AstraColors.dim),
        ],
      ),
    ),
  );
}

/// The rename dialog, which owns its own text controller.
///
/// A [StatefulWidget] rather than a controller created next to `showDialog`,
/// and the reason is a crash rather than tidiness. Disposing a controller the
/// moment `showDialog` returns disposes it while the dialog is still animating
/// out and its `TextField` is still listening — which trips
/// `_dependents.isEmpty` deep inside the framework and takes the whole screen
/// down to a red page.
///
/// Owning the controller here ties its life to the widget that uses it, so it
/// is disposed after the field is gone rather than before.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial});

  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Your name', style: AstraTextStyles.label),
    content: TextField(
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(hintText: 'What should we call you?'),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      TextButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}
