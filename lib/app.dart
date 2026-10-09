import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_v2_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/verify_email_screen.dart';
import 'services/auth_service.dart';
import 'theme/astra_theme.dart';
import 'widgets/aura_background.dart';

/// Which screen the app opens on.
///
/// The account comes first: sign in, then the questions, then the plan, then
/// the story. Onboarding ran first for a while — the argument being that
/// nobody makes an account for an app they have not seen do anything — and it
/// cost more than it bought.
///
/// The reason is that the answers are the account. They live on the device
/// until there is a uid to mirror them to, so with no account there is nothing
/// to attach twelve answers to and no way to recognise the person giving them.
/// Signing out cleared them and the app could not tell a returning user from a
/// new one; signing in on a second phone asked for all twelve again. Both are
/// the same missing fact — who is this — and asking for it up front is the only
/// thing that answers it.
///
/// Signing in first also means [AstraRepository.saveProfile] mirrors to
/// Firestore as each answer lands, rather than sitting on one device hoping an
/// account turns up later.
///
/// The exception is a build with no Firebase at all. There are no accounts to
/// sign into then, so asking would be a dead end; the app goes straight to
/// onboarding and runs on local storage, exactly as it always has.
class AstraApp extends ConsumerStatefulWidget {
  const AstraApp({super.key});

  @override
  ConsumerState<AstraApp> createState() => _AstraAppState();
}

class _AstraAppState extends ConsumerState<AstraApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-checks the subscription whenever the app comes back to the front.
  ///
  /// Cancelling happens in the Play Store, not in here, and Google does not
  /// tell the app about it — so someone who cancelled in another app and
  /// switched back was looking at a screen that still believed they were
  /// paying, until they killed the app entirely.
  ///
  /// Asking Play again on resume is the cheap fix: `restore` hands whatever
  /// Play currently knows to `verifyPurchase`, which rewrites the entitlement
  /// document, which the app is already streaming. The trip back from the Play
  /// Store is exactly when the answer has most likely changed.
  ///
  /// (The thorough fix is Real-time Developer Notifications — Play posting
  /// changes to a Pub/Sub topic the server listens on. That is worth doing when
  /// there are enough subscribers for a cancellation to matter before the next
  /// time they open the app; this covers the case a person can actually see.)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || user.isAnonymous) return;

    unawaited(
      ref.read(billingServiceProvider).restore().catchError(
            (Object error) =>
                debugPrint('Mayow: subscription re-check failed — $error'),
          ),
    );
  }

  String? _openedFor;

  @override
  Widget build(BuildContext context) {
    final firebaseReady = ref.watch(firebaseReadyProvider);
    final auth = ref.watch(authStateProvider);

    // Started here rather than in a screen: a purchase made on the hard
    // paywall has no account to attach to yet, and this is what claims it the
    // instant one exists. Watched at the root so it is listening before any
    // sign-in can happen.
    ref.watch(purchaseRestoreProvider);

    return MaterialApp(
      title: 'Mayow',
      debugShowCheckedModeBanner: false,
      theme: buildAstraTheme(),
      home: !firebaseReady
          ? const ShellScreen()
          : auth.when(
              // Only ever the first frame or two, while Firebase reads the
              // stored session. Anything more elaborate would flash.
              loading: () => const _Waiting(),
              // Auth itself failed to start. The sign-in screen is the only
              // honest thing to show — it is where a retry lives.
              error: (_, _) => const AuthScreen(),
              data: (user) {
                // The first fork, and now the only one that has to be read off
                // the account rather than off the device: nobody signed in
                // means sign in, whether this is a new phone or one that just
                // signed out.
                if (user == null) return const AuthScreen();

                // One report per signed-in session, for the admin panel.
                if (_openedFor != user.uid) {
                  _openedFor = user.uid;
                  unawaited(ref.read(trackingProvider).log('app_open'));
                }

                // An address nobody has proved is not an account yet: it could
                // be a stranger's, and a password reset would go to them. Only
                // password sign-ups land here — Google hands back an address
                // it already verified.
                //
                // Checked before the questions rather than after. The server
                // refuses to write a story for an unverified password account,
                // so leaving it until later would mean twelve answers and a
                // subscription bought by someone who still cannot generate
                // anything.
                if (AuthService.needsVerification(user)) {
                  return const VerifyEmailScreen();
                }

                // Wait for the account's own profile before drawing anything.
                //
                // Firestore is the source of truth for who this person is, and
                // it arrives a beat after the sign-in does. Home greets people
                // by name and writes in it, so opening before it lands shows a
                // stranger their own screen with the name missing.
                if (ref.watch(profileRestoreProvider).isLoading) {
                  return const _Waiting();
                }

                // The library comes back with them. Not waited on — an empty
                // Home that fills in a second later is fine, where an empty
                // *profile* would have routed them to the wrong screen
                // entirely. Watched rather than read so it actually runs.
                ref.watch(storiesRestoreProvider);

                // The belief-and-ritual questions — four of them, not the old
                // twelve — asked once, before Home is shown for the first
                // time. See [UserProfile.onboardingV2Done] for why this is a
                // separate flag from the old [UserProfile.isOnboarded].
                if (!ref.watch(profileProvider).onboardingV2Done) {
                  return const OnboardingV2Screen();
                }

                // No wish-flow onboarding, and no hard paywall. There is
                // nothing left to ask before somebody can use the app: the
                // four questions written for a *wish* are asked for the wish
                // they type, so they cannot be asked until they have typed
                // one.
                //
                // Everybody who is signed in gets the app.
                //
                // There used to be a hard paywall here: a new account went
                // from signing up straight to a price, before it had seen the
                // app do anything at all. That is the wrong place to ask. The
                // person has given us an email address and nothing else — they
                // have not typed a wish, they have not seen a question, they
                // have no idea yet what they would be buying.
                //
                // So the ask moved to the moment it makes sense: when they
                // press the button that writes something. By then they have
                // written their wish down, which is the whole pitch. Home,
                // Library, Affirm and Profile all open freely; the two calls
                // that cost money are the ones that check.
                //
                // Nothing is given away by moving it. The server refuses to
                // write a manifestation or a set of affirmations without a
                // live entitlement, and it refused before this change too —
                // the paywall here was never what protected the money, only
                // what decided which screen opened first.
                //
                // The exception: an account created by a build that sells the
                // free trial first. It stops at the paywall, with no way
                // forward but a trial, until the subscription exists. Accounts
                // made by older builds are not touched.
                final profile = ref.watch(profileProvider);
                if (profile.isGated && !user.isAnonymous) {
                  final entitlement = ref.watch(entitlementProvider);
                  if (entitlement.isLoading) return const _Waiting();
                  if (entitlement.valueOrNull != true) {
                    return PaywallScreen(
                      hard: true,
                      // Back goes to the questions, never to the app.
                      onBack: () => unawaited(
                        ref.read(profileProvider.notifier).update(
                          ref.read(profileProvider).copyWith(
                            onboardingV2Done: false,
                          ),
                        ),
                      ),
                    );
                  }
                }
                return const ShellScreen();
              },
            ),
    );
  }
}

/// The frame or two while Firebase reads the stored session.
///
/// It carries the same logo on the same paper as the native splash that was on
/// screen a moment ago, so the two read as one screen rather than as a launch
/// image that vanished and left the user looking at a spinner. The spinner is
/// still there, under the mark and small, because on a slow network this can
/// last long enough that something has to say the app is working.
class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuraBackground(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drawn at its own colours, and larger than it was.
            //
            // The old mark was a single-colour ink drawing, so it was tinted to
            // the text colour to keep it in the palette. The new one is purple,
            // gold and red — tinting it would flatten the whole thing to one
            // off-white silhouette and throw away the only piece of the brand
            // that has any colour in it.
            Image.asset(
              'assets/brand/splash_icon.png',
              width: 168,
              height: 168,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(height: AstraSpacing.xxl),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AstraColors.dim,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
