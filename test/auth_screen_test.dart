import 'package:astra/providers.dart';
import 'package:astra/screens/auth_screen.dart';
import 'package:astra/screens/forgot_password_screen.dart';
import 'package:astra/theme/astra_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The sign-in screen, tested for the things that are decisions rather than
/// decoration: that the free way in is visible, that the form refuses to
/// submit rubbish, and that the reset path exists.
///
/// Nothing here signs anyone in. That needs a live Firebase project, and a
/// test that pretends otherwise would be testing a mock's opinion of Firebase.
Future<Widget> _bootstrap() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      theme: buildAstraTheme(),
      home: const AuthScreen(),
    ),
  );
}

/// Pumps the screen on a viewport tall enough to hold all of it.
///
/// The default 800x600 test window leaves the lower buttons below the fold, and
/// a ListView does not build what it cannot show — so without this, half these
/// tests would be asserting on scroll position rather than on the screen.
Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(await _bootstrap());
  await tester.pumpAndSettle();
}

bool _armed(WidgetTester tester, String label) {
  final button = tester.widget<InkWell>(
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
  );
  return button.onTap != null;
}

void main() {
  testWidgets('both ways in are offered, and guest is not', (tester) async {
    await _pump(tester);

    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    // Guest sign-in is gone on purpose: an anonymous account cannot be signed
    // back into, so the library it holds dies with the phone.
    expect(find.text('Continue as guest'), findsNothing);
  });

  testWidgets('logging in needs an address and six characters', (tester) async {
    await _pump(tester);

    expect(_armed(tester, 'Log in'), isFalse);

    await tester.enterText(find.byType(TextField).first, 'not-an-email');
    await tester.enterText(find.byType(TextField).last, 'longenough');
    await tester.pumpAndSettle();
    expect(_armed(tester, 'Log in'), isFalse);

    await tester.enterText(find.byType(TextField).first, 'sana@example.com');
    await tester.enterText(find.byType(TextField).last, 'short');
    await tester.pumpAndSettle();
    expect(_armed(tester, 'Log in'), isFalse);

    await tester.enterText(find.byType(TextField).last, 'sixchars');
    await tester.pumpAndSettle();
    expect(_armed(tester, 'Log in'), isTrue);
  });

  testWidgets('the form switches between logging in and signing up', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.textContaining('Make one', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('Make an account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('forgot password is only offered where it applies', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Forgot password?'), findsOneWidget);

    // Nobody has forgotten the password of an account they are creating.
    await tester.tap(find.textContaining('Make one', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsNothing);
  });

  testWidgets('forgot password carries the typed address across', (
    tester,
  ) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).first, 'sana@example.com');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    // Retyping an address you just typed is the smallest possible insult, and
    // the most avoidable.
    expect(find.text('sana@example.com'), findsOneWidget);
  });

}
