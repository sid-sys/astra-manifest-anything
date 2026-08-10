import 'package:astra/providers.dart';
import 'package:astra/screens/onboarding_screen.dart';
import 'package:astra/theme/astra_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Widget> _bootstrap() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      theme: buildAstraTheme(),
      home: const OnboardingScreen(),
    ),
  );
}

void main() {
  testWidgets('onboarding opens on the name step', (tester) async {
    await tester.pumpWidget(await _bootstrap());

    expect(find.text('What should Astra call you?'), findsOneWidget);
  });

  testWidgets('onboarding asks for nothing but the three questions', (
    tester,
  ) async {
    await tester.pumpWidget(await _bootstrap());

    // No pricing, no plans, no card — the money conversation happens after
    // onboarding, on its own screen, and never inside these three steps.
    expect(find.textContaining('free'), findsNothing);
    expect(find.textContaining('₹'), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);
  });

  testWidgets('continue stays disabled until a name is entered', (
    tester,
  ) async {
    await tester.pumpWidget(await _bootstrap());

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What should Astra call you?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Sana');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('A little about you, Sana'), findsOneWidget);
  });

  testWidgets('age and gender can both be skipped', (tester) async {
    await tester.pumpWidget(await _bootstrap());

    await tester.enterText(find.byType(TextField), 'Sana');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Straight past without touching either field. An app that will not let
    // you past a gender question is an app people close, and the whole reason
    // for asking is that guessing was worse — a refusal to answer is a valid
    // answer.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('What are you calling in?'), findsOneWidget);
  });
}
