import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';
import 'paywall_screen.dart';
import 'shell_screen.dart';

/// Asks for the notification permission on its own screen, with a reason
/// attached, rather than firing the Android system dialog cold the instant
/// onboarding ends.
///
/// A permission prompt with no context attached is the one people deny on
/// reflex. This one says what it is for first, and "Not now" is offered as
/// plainly as the button that grants it — declining is a real choice here,
/// not a trap, because reminders are free to everybody and Home works
/// without them.
class NotificationPermissionScreen extends ConsumerStatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  ConsumerState<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends ConsumerState<NotificationPermissionScreen> {
  bool _busy = false;

  /// The paywall's own "Not now" is the skip. Whatever it returns — bought,
  /// skipped, or the back arrow — Home is where this ends either way, and
  /// nothing pushed to get here stays on the stack behind it.
  Future<void> _enter() async {
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PaywallScreen()),
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ShellScreen()),
      (route) => false,
    );
  }

  Future<void> _turnOn() async {
    setState(() => _busy = true);

    final granted = await ref.read(notificationServiceProvider).requestPermission();
    if (granted) {
      final profile = ref.read(profileProvider);
      await ref
          .read(profileProvider.notifier)
          .update(profile.copyWith(remindersOn: true));
      await refreshPushRegistration(ref);
    }

    if (!mounted) return;
    await _enter();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuraBackground(
      child: SafeArea(
        child: Padding(
          padding: AstraSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AstraSpacing.xxl),
              const Wordmark('Maya'),
              const Spacer(),
              Center(
                child: Icon(
                  Icons.notifications_active_rounded,
                  size: 72,
                  color: AstraColors.accent,
                ),
              ),
              const SizedBox(height: AstraSpacing.xl),
              Text(
                'Keep your intention close.',
                style: AstraTextStyles.display(28),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AstraSpacing.sm),
              Text(
                'Maya can send gentle reminders using your own affirmations.',
                style: AstraTextStyles.bodyDim,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AstraSpacing.xl),
              for (final (icon, title, body) in const [
                ('☀️', 'Morning', 'Start your day with your intention.'),
                ('✨', 'During the day', 'A gentle reminder of what you\'re working toward.'),
                ('🌙', 'Evening', 'End the day reconnecting with your goal.'),
              ]) ...[
                _Benefit(icon: icon, title: title, body: body),
                const SizedBox(height: AstraSpacing.md),
              ],
              const Spacer(),
              AstraButton(
                label: 'Turn on reminders',
                busy: _busy,
                onPressed: _busy ? null : _turnOn,
              ),
              const SizedBox(height: AstraSpacing.sm),
              AstraGhostButton(
                label: 'Not now',
                onPressed: _busy ? null : _enter,
              ),
              const SizedBox(height: AstraSpacing.sm),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.body});

  final String icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(icon, style: const TextStyle(fontSize: 22)),
      const SizedBox(width: AstraSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AstraTextStyles.label),
            const SizedBox(height: 2),
            Text(body, style: AstraTextStyles.small),
          ],
        ),
      ),
    ],
  );
}
