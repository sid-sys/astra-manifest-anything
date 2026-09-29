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
/// Three ways in, and the cheapest one is not hidden: "Continue as guest" is a
/// visible button rather than a link in small type, because the app works
/// without an account and pretending otherwise to harvest emails is the exact
/// complaint that made the app this one is modelled on a one-star read.
///
/// What the guest button costs is said next to it rather than discovered
/// later: an anonymous account has no password, so the library it holds cannot
/// be reached from another phone. Profile keeps offering to add an email, and
/// signing up from there links onto the same account rather than starting a
/// second one.
///
/// That upgrade path reuses this screen. [asUpgrade] only changes the words.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.asUpgrade = false});

  /// True when a guest is adding credentials to an account they already have.
  final bool asUpgrade;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// Opens on the sign-up form, both ways in.
  ///
  /// This screen is the app's front door now — it comes before onboarding —
  /// and nearly everyone who reaches it has no account yet. A returning user
  /// has a persisted session and never sees it; the ones who do signed out
  /// deliberately, and the toggle at the bottom is one tap away.
  ///
  /// Someone arriving by the upgrade route has already decided to have an
  /// account, so they want the same form. There is no case left that wants to
  /// open on log-in, which is why `initState` no longer sets this — it used to
  /// assign `widget.asUpgrade` here and quietly won against this initializer.
  bool _creating = true;
  bool _obscured = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// The name is asked for on sign-up only, and it is required.
  ///
  /// Every manifestation opens by saying it. Without one the writer is told to
  /// use "friend", and the very first thing a new user ever hears is a
  /// stranger calling them friend — which is the one line that had to land.
  /// Google accounts skip this box; the name comes off the credential.
  bool get _ready =>
      !_busy &&
      _email.text.contains('@') &&
      _password.text.trim().length >= 6 &&
      (!_creating || _name.text.trim().length >= 2);

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

    // Read before the await. A successful sign-up swaps this whole screen out
    // from under itself — the app watches the auth stream — so `ref` may be
    // dead by the time the name is written. The notifier outlives the widget.
    final profile = ref.read(profileProvider.notifier);
    final creating = _creating;
    final name = _name.text;

    final done = await _run(
      () async => creating
          ? await auth.signUpWithEmail(_email.text, _password.text)
          : await auth.signInWithEmail(_email.text, _password.text),
    );

    // Saved after the account exists, so it is written against a real uid and
    // mirrors to Firestore rather than sitting on this one phone.
    if (done && creating) await profile.setName(name);

    // Only an upgrade navigates. Arriving here from the door needs nothing:
    // the app watches the auth stream and swaps this screen out the moment a
    // user exists. An upgrade started from Profile is a pushed route, so it
    // has to take itself back off.
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
                const Wordmark('Maya'),
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
                      ? 'Six characters or more. We send a link to confirm the '
                            'address — your stories sync to this account and '
                            'follow you between devices.'
                      : 'Sign in and your library comes with you.',
                  textAlign: TextAlign.center,
                  style: AstraTextStyles.bodyDim,
                ),
                const SizedBox(height: AstraSpacing.xl),

                // Sign-up only. Someone logging back in has a name already,
                // and asking again would be asking them to confirm a fact the
                // app is holding.
                if (_creating) ...[
                  _Field(
                    controller: _name,
                    label: 'Your first name',
                    hint: 'What should Maya call you?',
                    icon: Icons.person_outline_rounded,
                    keyboardType: TextInputType.name,
                    autofillHints: const [AutofillHints.givenName],
                    textCapitalization: TextCapitalization.words,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: AstraSpacing.md),
                ],
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

                // The guest door was here, twice, and is closed again.
                //
                // An anonymous account has no password and no address, so the
                // library it holds cannot be reached from any other phone and
                // nobody can return it to its owner — a reinstall loses
                // everything, silently.
                //
                // The second attempt failed for a subtler reason worth keeping.
                // Signing in with Google while a guest was active *links* the
                // two rather than replacing one, so the guest's sample profile
                // survived onto the real account: a brand new user was carried
                // past onboarding on somebody else's answers and dropped
                // straight onto the paywall, never having been asked a single
                // question.
                const SizedBox(height: AstraSpacing.sm),
                Text(
                  'Your stories are saved to your account, so they follow you '
                  'to a new phone.',
                  textAlign: TextAlign.center,
                  style: AstraTextStyles.small,
                ),

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
    this.textCapitalization = TextCapitalization.none,
    this.obscure = false,
    this.trailing,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final TextCapitalization textCapitalization;
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
        textCapitalization: textCapitalization,
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
            borderSide: BorderSide(color: AstraColors.line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AstraSpacing.cardRadius),
            borderSide: BorderSide(color: AstraColors.accent),
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
      Expanded(child: Divider(color: AstraColors.line)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AstraSpacing.md),
        child: Text('or', style: AstraTextStyles.small),
      ),
      Expanded(child: Divider(color: AstraColors.line)),
    ],
  );
}

/// One of the non-password ways in. Bordered rather than filled — the primary
/// action on this screen is the form above it.
class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.glyph,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  /// The provider's mark, as a letter. Google is the only provider left since
  /// the guest door closed, and its mark is a "G" rather than a Material icon.
  final String glyph;

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
                Text(
                  glyph,
                  style: AstraTextStyles.label.copyWith(fontSize: 17),
                ),
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
