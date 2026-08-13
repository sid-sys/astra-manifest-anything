import 'package:astra/providers.dart';
import 'package:astra/screens/onboarding_screen.dart';
import 'package:astra/theme/astra_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding asks nine questions now, and only two of them are compulsory.
///
/// That ratio is the thing worth testing. Every extra question is a chance to
/// lose someone, and the case for asking nine is that the answers make the
/// stories specific — which only holds if the seven optional ones can genuinely
/// be walked past.
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

/// Pumps on a viewport tall enough that a step's lower half is built. A
/// ListView does not build what it cannot show, so on the default 800x600 the
/// assertions would be about scroll position rather than about the screen.
Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(await _bootstrap());
  await tester.pumpAndSettle();
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onboarding opens on the name step', (tester) async {
    await _pump(tester);

    expect(find.text('What should Astra call you?'), findsOneWidget);
  });

  testWidgets('onboarding says where you are in it', (tester) async {
    await _pump(tester);

    // A bar alone says "partway". The count is what answers the only question
    // anyone has while filling in a form — and it matters more at nine steps
    // than it did at four.
    expect(find.text('STEP 1 OF 9'), findsOneWidget);
    expect(find.text('YOU'), findsOneWidget);
  });

  testWidgets('the questions themselves never mention money', (tester) async {
    await _pump(tester);

    // The plans are a route of their own, shown after the desire. What must
    // not happen is a price appearing inside a step, beside a field someone is
    // being asked to fill in.
    expect(find.textContaining('₹'), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.textContaining('month'), findsNothing);
  });

  testWidgets('continue stays disabled until a name is entered', (
    tester,
  ) async {
    await _pump(tester);

    await _continue(tester);
    expect(find.text('What should Astra call you?'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Sana');
    await tester.pumpAndSettle();
    await _continue(tester);

    expect(find.text('What do you want to visualise, Sana?'), findsOneWidget);
  });

  testWidgets('the desire is the second thing that cannot be skipped', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Sana');
    await tester.pumpAndSettle();
    await _continue(tester);

    // Still on the desire step: there is nothing to write a story from.
    await _continue(tester);
    expect(find.text('What do you want to visualise, Sana?'), findsOneWidget);
  });

  testWidgets('age and gender can both be skipped', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Sana');
    await tester.pumpAndSettle();

    // Straight past without touching either field. An app that will not let
    // you past a gender question is an app people close, and the whole reason
    // for asking is that guessing was worse — a refusal to answer is a valid
    // answer.
    await _continue(tester);

    expect(find.text('What do you want to visualise, Sana?'), findsOneWidget);
  });

  testWidgets('every step after the desire opens already passable', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'Sana');
    await tester.pumpAndSettle();
    await _continue(tester);

    await tester.enterText(
      find.byType(TextField).last,
      'I run my own studio in Kochi',
    );
    await tester.pumpAndSettle();
    await _continue(tester);

    // The plans, offered once, straight after the desire. "Not now" is a real
    // answer that carries on to the free story — which is the whole reason it
    // sits here rather than in front of the app.
    //
    // The paywall asks the store for live prices on open, and there is no
    // Firebase in a widget test, so it throws on the way in. Swallowed here
    // rather than mocked: what this test is about is that the seven optional
    // steps can be walked past, and the paywall's price lookup already falls
    // back to the local catalogue in the app.
    tester.takeException();
    expect(find.text('Not now'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    // Steps three to eight: timeline, people, place, feelings, future, telling.
    // Each answered by not answering, which is the promise the whole flow
    // rests on.
    for (var step = 3; step <= 8; step++) {
      expect(find.text('STEP $step OF 9'), findsOneWidget);
      await _continue(tester);
    }

    expect(find.text('STEP 9 OF 9'), findsOneWidget);
    expect(find.text('Write my first story'), findsOneWidget);
  });
}
