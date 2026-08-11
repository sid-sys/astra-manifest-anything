import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';

/// What the user is about to do, and how hard it should be to do by accident.
enum ConfirmKind {
  /// Ends the session. On an anonymous account this abandons the cloud copy.
  signOut,

  /// Erases the account and everything under it, everywhere.
  deleteData,
}

/// A full screen for the two actions that cannot be undone.
///
/// A screen rather than a dialog, and deliberately so: a dialog is dismissed
/// with a tap anywhere and is read as a speed bump, while this makes the user
/// leave what they were doing, read a list of exactly what goes, and come back.
/// Deleting additionally asks for the word to be typed — not theatre, but the
/// difference between a mis-tap and a decision.
class ConfirmScreen extends ConsumerStatefulWidget {
  const ConfirmScreen({super.key, required this.kind});

  final ConfirmKind kind;

  @override
  ConsumerState<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends ConsumerState<ConfirmScreen> {
  static const _phrase = 'DELETE';

  final _typed = TextEditingController();
  bool _working = false;
  String? _error;

  bool get _isDelete => widget.kind == ConfirmKind.deleteData;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  bool get _armed =>
      !_working && (!_isDelete || _typed.text.trim().toUpperCase() == _phrase);

  Future<void> _confirm() async {
    if (!_armed) return;
    setState(() {
      _working = true;
      _error = null;
    });

    final account = ref.read(accountServiceProvider);

    try {
      if (_isDelete) {
        // Server first. If it throws, the device keeps its copy and the user
        // is told the truth — a local wipe over a failed delete would leave
        // them believing data is gone while it sits in Firestore.
        await account.deleteEverything();
        await forgetEverythingLocal(ref);
      } else {
        await account.signOut();
        await forgetEverythingLocal(ref);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = 'That did not go through. Your data is still here. '
            'Check your connection and try again.';
      });
      return;
    }

    if (!mounted) return;
    // The app routes on whether a profile exists, so emptying it has already
    // put the onboarding screen underneath. Closing this leaves the user there
    // rather than on a screen belonging to an account that no longer exists.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final stories = ref.watch(storiesProvider).length;
    final kept = ref.watch(tasteProvider).liked.length;

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Padding(
            padding: AstraSpacing.screenPadding,
            child: ListView(
              children: [
                const SizedBox(height: AstraSpacing.sm),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: AstraColors.dim,
                      tooltip: 'Back',
                      onPressed: _working
                          ? null
                          : () => Navigator.of(context).maybePop(),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: AstraSpacing.lg),

                Text(
                  _isDelete ? 'Delete everything?' : 'Log out?',
                  style: AstraTextStyles.display(28),
                ),
                const SizedBox(height: AstraSpacing.sm),
                Text(
                  _isDelete
                      ? 'This removes your account and everything in it, from '
                            'this device and from Astra\'s servers. It cannot '
                            'be undone and there is no copy to restore from.'
                      : 'Your stories stay on our servers and come back when '
                            'you log in again. This device is cleared.',
                  style: AstraTextStyles.bodyDim,
                ),
                const SizedBox(height: AstraSpacing.xl),

                AstraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isDelete ? 'WHAT GOES' : 'CLEARED FROM THIS DEVICE',
                        style: AstraTextStyles.eyebrow,
                      ),
                      const SizedBox(height: AstraSpacing.md),
                      _Item(
                        icon: Icons.library_music_outlined,
                        label: stories == 1
                            ? '1 story, with its audio'
                            : '$stories stories, with their audio',
                      ),
                      _Item(
                        icon: Icons.favorite_border,
                        label: kept == 1
                            ? '1 kept affirmation'
                            : '$kept kept affirmations',
                      ),
                      const _Item(
                        icon: Icons.person_outline,
                        label: 'Your name, intentions and streak',
                      ),
                      if (_isDelete)
                        const _Item(
                          icon: Icons.cloud_off_rounded,
                          label: 'The backup on our servers',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AstraSpacing.lg),

                if (_isDelete) ...[
                  Text(
                    'Type $_phrase to confirm',
                    style: AstraTextStyles.small,
                  ),
                  const SizedBox(height: AstraSpacing.sm),
                  TextField(
                    controller: _typed,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [LengthLimitingTextInputFormatter(12)],
                    style: AstraTextStyles.body,
                    cursorColor: AstraColors.accent,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: _phrase,
                      hintStyle: AstraTextStyles.bodyDim,
                      filled: true,
                      fillColor: AstraColors.card,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AstraSpacing.cardRadius,
                        ),
                        borderSide: const BorderSide(color: AstraColors.line),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AstraSpacing.cardRadius,
                        ),
                        borderSide: const BorderSide(color: AstraColors.accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: AstraSpacing.lg),
                ],

                if (_error != null) ...[
                  Text(
                    _error!,
                    style: AstraTextStyles.small.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AstraSpacing.md),
                ],

                _DangerButton(
                  label: _isDelete ? 'Delete everything' : 'Log out',
                  busy: _working,
                  onPressed: _armed ? _confirm : null,
                ),
                const SizedBox(height: AstraSpacing.sm),
                AstraGhostButton(
                  label: 'Keep my data',
                  onPressed:
                      _working ? null : () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: AstraSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AstraSpacing.sm),
    child: Row(
      children: [
        Icon(icon, size: 16, color: AstraColors.dim),
        const SizedBox(width: AstraSpacing.md),
        Expanded(child: Text(label, style: AstraTextStyles.body)),
      ],
    ),
  );
}

/// The destructive action, in the app's error colour rather than its gold.
///
/// Gold is the colour of everything Astra wants you to press. This one it does
/// not, so it does not get the house button.
class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;
    final enabled = onPressed != null && !busy;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: danger.withValues(alpha: 0.12),
                border: Border.all(color: danger),
                borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
              ),
              child: busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: danger,
                      ),
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: danger,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
