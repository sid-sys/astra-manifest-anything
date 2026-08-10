import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../services/auth_service.dart';
import '../theme/astra_theme.dart';
import '../widgets/astra_widgets.dart';
import '../widgets/aura_background.dart';
import 'forgot_password_screen.dart';

/// The door.
///
/// Four ways in, and the cheapest one is not hidden: "Continue as guest" is a
/// visible button rather than a link in small type, because the app works
/// without an account and pretending otherwise to harvest emails is the exact
/// complaint that made the app this one is modelled on a one-star read.
///
/// It is also shown when a guest chooses to upgrade, in which case the same
/// form links the credentials onto their existing account and keeps their
/// stories. [asUpgrade] only changes the words.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.asUpgrade = false});

  final bool asUpgrade;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _creating = false;
  bool _obscured = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Someone upgrading has already decided to have an account; open on the
    // form that makes one.
    _creating = widget.asUpgrade;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _ready =>
      !_busy &&
      _email.text.contains('@') &&
      _password.text.trim().length >= 6;

  /// Runs [action], turning any auth failure into a line the user can act on.
  ///
  /// Returns true when it worked. Nothing navigates on success: the app is
  /// listening to the auth stream, so the tree swaps itself out from under
  /// this screen the moment a user exists.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await action();
      return true;
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = authErrorMessage(error);
        });
      }
      return false;
    }
  }

  Future<void> _submitEmail() async {
    if (!_ready) return;
    final auth = ref.read(authServiceProvider);

    final done = await _run(
      () async => _creating
          ? await auth.signUpWithEmail(_email.text, _password.text)
          : await auth.signInWithEmail(_email.text, _password.text),
    );

    if (done && mounted && widget.asUpgrade) Navigator.of(context).pop(true);
  }

  Future<void> _federated(Future<void> Function() signIn) async {
    final done = await _run(signIn);
    if (done && mounted && widget.asUpgrade) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);

    return Scaffold(
      body: AuraBackground(
        child: SafeArea(
          child: Padding(
            padding: AstraSpacing.screenPadding,
            child: ListView(
              children: [
                if (widget.asUpgrade)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        color: AstraColors.dim,
                        tooltip: 'Back',
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).maybePop(),
                      ),
                      const Spacer(),
                    ],
                  )
                else
                  const SizedBox(height: AstraSpacing.xxl),

                const SizedBox(height: AstraSpacing.lg),
                const Wordmark('Astra'),
                const SizedBox(height: AstraSpacing.xl),
                Text(
                  widget.asUpgrade
                      ? 'Keep your stories safe'
                      : _creating
                          ? 'Make an account'
                          : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: AstraTextStyles.display(28),
                ),
                const SizedBox(height: AstraSpacing.sm),
                Text(
                  widget.asUpgrade
                      ? 'Adding an email keeps everything you have already '
                            'written and lets you sign in on another phone. '
                            'You will confirm the address by email before '
                            'writing anything new.'
                      : _creating
                          ? 'Six characters or more. We send a link to confirm '
                                'the address — your stories sync to this '
                                'account and follow you between devices.'
                          : 'Sign in and your library comes with you.',
                  textAlign: TextAlign.center,
                  style: AstraTextStyles.bodyDim,
                ),
                const SizedBox(height: AstraSpacing.xl),

                _Field(
                  controller: _email,
                  label: 'Email',
                  hint: 'you@example.com',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: AstraSpacing.md),
                _Field(
                  controller: _password,
                  label: 'Password',
                  hint: '••••••',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscured,
                  autofillHints: [
                    _creating
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  onChanged: () => setState(() {}),
                  onSubmitted: _submitEmail,
                  trailing: IconButton(
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                      color: AstraColors.dim,
                    ),
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscured = !_obscured),
                  ),
                ),

                if (!_creating) ...[
                  const SizedBox(height: AstraSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ForgotPasswordScreen(
                                    email: _email.text,
                                  ),
                                ),
                              ),
                      child: Text(
                        'Forgot password?',
                        style: AstraTextStyles.small.copyWith(
                          color: AstraColors.accent,
                        ),
                      ),
                    ),
                  ),
                ],

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
                  label: _creating ? 'Create account' : 'Log in',
                  busy: _busy,
                  onPressed: _ready ? _submitEmail : null,
                ),

                const SizedBox(height: AstraSpacing.lg),
                const _Divider(),
                const SizedBox(height: AstraSpacing.lg),

                _ProviderButton(
                  label: 'Continue with Google',
                  glyph: 'G',
                  enabled: !_busy,
                  onTap: () => _federated(auth.signInWithGoogle),
                ),

                if (!widget.asUpgrade) ...[
                  const SizedBox(height: AstraSpacing.sm),
                  _ProviderButton(
                    label: 'Continue as guest',
                    icon: Icons.person_outline_rounded,
                    enabled: !_busy,
                    onTap: () => _federated(auth.continueAsGuest),
                  ),
                  const SizedBox(height: AstraSpacing.sm),
                  Text(
                    'A guest account works exactly the same. You can add an '
                    'email later without losing anything.',
                    textAlign: TextAlign.center,
                    style: AstraTextStyles.small,
                  ),
                ],

                const SizedBox(height: AstraSpacing.lg),
                Center(
                  child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _creating = !_creating;
                              _error = null;
                            }),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: _creating
                                ? 'Already have an account?  '
                                : 'New here?  ',
                            style: AstraTextStyles.small,
                          ),
                          TextSpan(
                            text: _creating ? 'Log in' : 'Make one',
                            style: AstraTextStyles.small.copyWith(
                              color: AstraColors.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

/// A labelled input, shaped like the rest of the app's cards.
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onChanged,
    this.keyboardType,
    this.autofillHints,
    this.obscure = false,
    this.trailing,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final VoidCallback onChanged;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscure;
  final Widget? trailing;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AstraTextStyles.small),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        autocorrect: false,
        enableSuggestions: false,
        style: AstraTextStyles.body,
        cursorColor: AstraColors.accent,
        onChanged: (_) => onChanged(),
        onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AstraTextStyles.bodyDim,
          prefixIcon: Icon(icon, size: 18, color: AstraColors.dim),
          suffixIcon: trailing,
          filled: true,
          fillColor: AstraColors.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
            borderSide: const BorderSide(color: AstraColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
            borderSide: const BorderSide(color: AstraColors.accent),
          ),
        ),
      ),
    ],
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(color: AstraColors.line)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AstraSpacing.md),
        child: Text('or', style: AstraTextStyles.small),
      ),
      const Expanded(child: Divider(color: AstraColors.line)),
    ],
  );
}

/// One of the non-password ways in. Bordered rather than gold — the primary
/// action on this screen is the form above it.
class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.icon,
    this.glyph,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final IconData? icon;

  /// Used for Google, whose mark is a letter rather than a Material icon.
  final String? glyph;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    label: label,
    child: Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AstraColors.card,
              border: Border.all(color: AstraColors.line),
              borderRadius: BorderRadius.circular(AstraSpacing.pillRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (glyph != null)
                  Text(
                    glyph!,
                    style: AstraTextStyles.label.copyWith(fontSize: 17),
                  )
                else
                  Icon(icon, size: 19, color: AstraColors.text),
                const SizedBox(width: AstraSpacing.md),
                Text(label, style: AstraTextStyles.body),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
