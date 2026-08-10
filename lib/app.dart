import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'screens/verify_email_screen.dart';
import 'services/auth_service.dart';
import 'theme/astra_theme.dart';
import 'widgets/aura_background.dart';

/// Which screen the app opens on.
///
/// Three questions, in order: is there an account, has its address been
/// proved, and has it been set up. The
/// sign-in screen comes first because everything after it writes to a uid —
/// onboarding included, since the name and intentions it collects are the
/// first thing mirrored to Firestore.
///
/// The exception is a build with no Firebase at all. There are no accounts to
/// sign into then, so asking would be a dead end; the app goes straight to
/// onboarding and runs on local storage, exactly as it always has.
class AstraApp extends ConsumerWidget {
  const AstraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(
      profileProvider.select((profile) => profile.isOnboarded),
    );
    final firebaseReady = ref.watch(firebaseReadyProvider);
    final auth = ref.watch(authStateProvider);

    return MaterialApp(
      title: 'Astra',
      debugShowCheckedModeBanner: false,
      theme: buildAstraTheme(),
      home: !firebaseReady
          ? (onboarded ? const ShellScreen() : const OnboardingScreen())
          : auth.when(
              // Only ever the first frame or two, while Firebase reads the
              // stored session. Anything more elaborate than the starfield
              // would flash.
              loading: () => const _Waiting(),
              error: (_, _) => const AuthScreen(),
              data: (user) => user == null
                  ? const AuthScreen()
                  // An address nobody has proved is not an account yet: it
                  // could be a stranger's, and a password reset would go to
                  // them. Only password sign-ups land here — Google hands back
                  // an address it already verified, and a guest has none.
                  : AuthService.needsVerification(user)
                      ? const VerifyEmailScreen()
                      : onboarded
                          ? const ShellScreen()
                          : const OnboardingScreen(),
            ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: AuraBackground(
      child: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AstraColors.accent,
          ),
        ),
      ),
    ),
  );
}
