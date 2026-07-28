import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'theme/astra_theme.dart';

class AstraApp extends ConsumerWidget {
  const AstraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(
      profileProvider.select((profile) => profile.isOnboarded),
    );

    return MaterialApp(
      title: 'Astra',
      debugShowCheckedModeBanner: false,
      theme: buildAstraTheme(),
      home: onboarded ? const ShellScreen() : const OnboardingScreen(),
    );
  }
}
