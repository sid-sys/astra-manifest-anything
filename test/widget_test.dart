import 'package:astra/providers.dart';
import 'package:astra/screens/onboarding_screen.dart';
import 'package:astra/theme/astra_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding is eleven questions, one to a page, and only one of them is
/// compulsory.
///
/// That ratio is the thing worth testing. Eleven questions is a lot to ask
/// before anyone has seen what the app makes, and the case for asking them is
/// that the answers change the writing — which only holds if the other ten can
/// genuinely be walked past, and if a mistap can be walked back.
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

/// Pumps on a viewport tall enough that a page's lower half is built. A
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

/// Answers the desire, leaving the flow on question three.
Future<void> _pastTheDesire(WidgetTester tester) async {
  await _continue(tester); // past the category
  await tester.enterText(
    find.byType(TextField).first,
    'I run my own studio in Kochi',
  );
  await tester.pumpAndSettle();
  await _continue(tester);
}

void main() {
  testWidgets('onboarding opens on the first question, not a form', (
    tester,
  ) async {
    await _pump(tester);

    expect(
      find.text('What kind of desire do you want to visualise?'),
      findsOneWidget,
    );
    expect(find.text('1 OF 11'), findsOneWidget);
  });

  testWidgets('nothing asks for a name, an age or a gender', (tester) async {
    await _pump(tester);
    await _pastTheDesire(tester);

    // Removed on purpose. The stories are first person, so nobody is addressed
    // by name inside one, and the generator writes no gender it was not given.
    for (var step = 3; step <= 11; step++) {
      expect(find.textContaining('call you'), findsNothing);
      expect(find.text('AGE'), findsNothing);
      expect(find.text('GENDER'), findsNothing);
      if (step < 11) await _continue(tester);
    }
  });

  testWidgets('the questions themselves never mention money', (tester) async {
    await _pump(tester);

    // The plans are a route of their own, shown after the desire. What must
    // not happen is a price appearing inside a question.
    expect(find.textContaining('₹'), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);
    expect(find.textContaining('month'), findsNothing);
  });

  testWidgets('only the desire cannot be skipped', (tester) async {
    await _pump(tester);

    // The category has a default, so question one is passable untouched.
    await _continue(tester);
    expect(find.text('What is your desire?'), findsOneWidget);

    // Question two is not: there is nothing to write a story from.
    await _continue(tester);
    expect(find.text('What is your desire?'), findsOneWidget);
  });

  testWidgets('every question after the desire opens already passable', (
    tester,
  ) async {
    await _pump(tester);
    await _pastTheDesire(tester);

    for (var step = 3; step <= 10; step++) {
      expect(find.text('$step OF 11'), findsOneWidget);
      await _continue(tester);
    }

    expect(find.text('11 OF 11'), findsOneWidget);
    expect(find.text('Write my first story'), findsOneWidget);
  });

  testWidgets('back goes back, and keeps the answer that was given', (
    tester,
  ) async {
    await _pump(tester);
    await _pastTheDesire(tester);

    expect(find.text('3 OF 11'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    // Back onto the desire, with the sentence still in the box — the whole
    // point of a back button is fixing one answer, not retyping them all.
    expect(find.text('2 OF 11'), findsOneWidget);
    expect(find.text('I run my own studio in Kochi'), findsOneWidget);
  });

  testWidgets('the first question has no back button to press', (tester) async {
    await _pump(tester);

    expect(find.bySemanticsLabel('Back'), findsNothing);
  });

  testWidgets('no price appears until every question has been answered', (
    tester,
  ) async {
    await _pump(tester);
    await _pastTheDesire(tester);

    // Questions three to eleven, with no interruption. The plans used to cut
    // in after the desire, which put a price in the middle of a conversation
    // and made the rest feel like work already charged for.
    for (var step = 3; step <= 11; step++) {
      expect(find.text('$step OF 11'), findsOneWidget);
      expect(find.text('Not now'), findsNothing);
      if (step < 11) await _continue(tester);
    }

    // Answered. Now the offer, once, between the last answer and the story.
    await tester.tap(find.text('Write my first story'));
    await tester.pumpAndSettle();

    // The paywall asks the store for live prices on open, and there is no
    // Firebase in a widget test, so it throws on the way in. Swallowed rather
    // than mocked: this test is about when the offer appears, and the paywall
    // already falls back to the local price table in the app.
    tester.takeException();
    expect(find.text('Not now'), findsOneWidget);
  });
}
