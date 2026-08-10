import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/auth_service.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';

/// The wall between signing up and using the app.
///
/// Firebase verifies an address with a link, not a code — there is no six-digit
/// number to type, and inventing one would mean running an email service and a
/// code store to reproduce what the link already proves. So this screen's job
/// is to wait well: it polls quietly, offers a resend, and lets someone leave
/// with the address they mistyped rather than trapping them.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _poll;
  bool _checking = false;
  bool _resending = false;
  String? _note;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Clicking the link happens in another app — a mail client, usually on
    // another device — so nothing tells this screen it happened. Asking every
    // four seconds is cheap and means the user comes back to an app that has
    // already let them in.
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check({bool loud = false}) async {
    if (_checking) return;
    if (loud) setState(() => _checking = true);

    try {
      final verified = await ref
          .read(authServiceProvider)
          .refreshVerification();

      if (!mounted) return;
      if (verified) {
        _poll?.cancel();
        // Nothing to navigate: the app is watching the auth state and swaps
        // this screen out the moment the token says verified.
        ref.invalidate(authStateProvider);
      } else if (loud) {
        setState(() => _note = 'Not yet. Click the link, then try again.');
      }
    } catch (error) {
      if (mounted && loud) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted && loud) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _note = null;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).sendVerificationEmail();
      if (mounted) setState(() => _note = 'Sent. Give it a minute.');
    } catch (error) {
      if (mounted) setState(() => _error = authErrorMessage(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _startOver() async {
    // Signing out is the way back to the sign-in screen, and the only way to
    // fix an address with a typo in it.
    await ref.read(accountServiceProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authStateProvider).valueOrNull?.email ?? 'your inbox';

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Padding(
            padding: AstraSpacing.screenPadding,
            child: ListView(
              children: [
                const SizedBox(height: AstraSpacing.xxl),
                const Wordmark('Astra'),
                const SizedBox(height: AstraSpacing.xxl),

                const Center(
                  child: GlyphDot(glyph: '✉', size: 72),
                ),
                const SizedBox(height: AstraSpacing.xl),

                Text(
                  'Check your email',
                  textAlign: TextAlign.center,
                  style: AstraTextStyles.display(28),
                ),
                const SizedBox(height: AstraSpacing.sm),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'We sent a link to '),
                      TextSpan(
                        text: email,
                        style: AstraTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(
                        text:
                            '. Click it and this screen will let you through on '
                            'its own. Check spam if it has not arrived in a '
                            'few minutes.',
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: AstraTextStyles.bodyDim,
                ),
                const SizedBox(height: AstraSpacing.lg),

                if (_note != null)
                  Text(
                    _note!,
                    textAlign: TextAlign.center,
                    style: AstraTextStyles.small.copyWith(
                      color: AstraColors.accent,
                    ),
                  ),
                if (_error != null)
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AstraTextStyles.small.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: AstraSpacing.lg),

                AstraButton(
                  label: "I've clicked it",
                  busy: _checking,
                  onPressed: () => _check(loud: true),
                ),
                const SizedBox(height: AstraSpacing.sm),
                AstraGhostButton(
                  label: _resending ? 'Sending…' : 'Send it again',
                  onPressed: _resending ? null : _resend,
                ),
                const SizedBox(height: AstraSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: _startOver,
                    child: Text(
                      'Wrong address? Start over',
                      style: AstraTextStyles.small.copyWith(
                        color: AstraColors.accent,
                      ),
                    ),
                  ),
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
