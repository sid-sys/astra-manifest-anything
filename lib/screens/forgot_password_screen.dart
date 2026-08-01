import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/auth_service.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/starfield.dart';

/// Sends the reset link, then says so without saying too much.
///
/// The confirmation deliberately does not reveal whether the address has an
/// account: "if there is an account, a link is on its way" is the same
/// sentence either way, so a stranger with this form cannot use it to find out
/// who is registered. Firebase's own error for an unknown address is swallowed
/// for the same reason.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.email = ''});

  /// Prefilled from the login form, so nobody types their address twice.
  final String email;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _email = TextEditingController(
    text: widget.email,
  );

  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool get _ready => !_busy && _email.text.contains('@');

  Future<void> _send() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authServiceProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (error) {
      if (!mounted) return;
      // An unknown address is not an error the user should see: telling them
      // would confirm which addresses are registered. Anything else — no
      // network, a malformed address, rate limiting — is worth showing.
      final message = authErrorMessage(error);
      setState(() {
        _sent = message == 'That email and password do not match.';
        _error = _sent ? null : message;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Starfield(
      child: SafeArea(
        child: Padding(
          padding: AstraSpacing.screenPadding,
          child: ListView(
            children: [
              const SizedBox(height: AstraSpacing.sm),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AstraColors.dim,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: AstraSpacing.lg),

              Text(
                _sent ? 'Check your email' : 'Reset your password',
                style: AstraTextStyles.display(28),
              ),
              const SizedBox(height: AstraSpacing.sm),
              Text(
                _sent
                    ? 'If there is an account for ${_email.text.trim()}, a '
                          'link to set a new password is on its way. It '
                          'expires in an hour. Check spam if it has not '
                          'arrived in a few minutes.'
                    : 'Enter the email you signed up with and we will send a '
                          'link to set a new one.',
                style: AstraTextStyles.bodyDim,
              ),
              const SizedBox(height: AstraSpacing.xl),

              if (!_sent) ...[
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.email],
                  style: AstraTextStyles.body,
                  cursorColor: AstraColors.gold,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    hintStyle: AstraTextStyles.bodyDim,
                    prefixIcon: const Icon(
                      Icons.alternate_email_rounded,
                      size: 18,
                      color: AstraColors.dim,
                    ),
                    filled: true,
                    fillColor: AstraColors.card,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                      borderSide: const BorderSide(color: AstraColors.gold),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AstraSpacing.sm),
                  Text(
                    _error!,
                    style: AstraTextStyles.small.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: AstraSpacing.lg),
                AstraButton(
                  label: 'Send the link',
                  busy: _busy,
                  onPressed: _ready ? _send : null,
                ),
              ] else ...[
                AstraButton(
                  label: 'Back to login',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(height: AstraSpacing.sm),
                AstraGhostButton(
                  label: 'Send it again',
                  onPressed: _busy ? null : () => setState(() => _sent = false),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
