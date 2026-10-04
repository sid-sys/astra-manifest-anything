import 'package:astra/providers.dart';
import 'package:astra/screens/auth_screen.dart';
import 'package:astra/screens/forgot_password_screen.dart';
import 'package:astra/theme/astra_theme.dart';
import 'package:astra/widgets/astra_widgets.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The account screen, tested for the things that are decisions rather than
/// decoration: that it opens on sign-up, that the free way in is visible, that
/// the form refuses to submit rubbish, and that the reset path exists.
///
/// It opens on sign-up because it is the app's front door — it now comes
/// before onboarding, so almost everyone reaching it has no account. Anyone
/// who does has a persisted session and never sees this screen at all.
///
/// Nothing here signs anyone in. That needs a live Firebase project, and a
/// test that pretends otherwise would be testing a mock's opinion of Firebase.
Future<Widget> _bootstrap({bool asUpgrade = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      theme: buildAstraTheme(),
      home: AuthScreen(asUpgrade: asUpgrade),
    ),
  );
}

/// Pumps the screen on a viewport tall enough to hold all of it.
///
/// The default 800x600 test window leaves the guest button below the fold, and
/// a ListView does not build what it cannot show — so without this, half these
/// tests would be asserting on scroll position rather than on the screen.
Future<void> _pump(WidgetTester tester, {bool asUpgrade = false}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(await _bootstrap(asUpgrade: asUpgrade));
  await tester.pumpAndSettle();
}

bool _armed(WidgetTester tester, String label) {
  // The primary button is an AstraButton, which presses through a gesture
  // detector rather than an InkWell, so ask the button itself whether it has
  // an action. Anything else with this label (a text link) is still an InkWell.
  final primary = find.ancestor(
    of: find.text(label),
    matching: find.byType(AstraButton),
  );
  if (primary.evaluate().isNotEmpty) {
    return tester.widget<AstraButton>(primary.first).onPressed != null;
  }

  final button = tester.widget<InkWell>(
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
  );
  return button.onTap != null;
}

void main() {
  testWidgets('it opens on sign-up, not on log-in', (tester) async {
    await _pump(tester);

    // The front door for a new user. This used to open on "Welcome back",
    // which asked people without accounts to remember a password they had
    // never set.
    expect(find.text('Make an account'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('both ways in are offered', (tester) async {
    await _pump(tester);

    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('there is no way in without credentials', (tester) async {
    await _pump(tester);

    // The guest door has been closed twice now, and the second reason is the
    // one worth remembering. Signing in with Google while a guest was active
    // *links* the accounts rather than replacing one, so the guest's sample
    // profile survived onto the real account: a brand new user was carried past
    // onboarding on answers that were never theirs and dropped straight onto
    // the paywall, having been asked nothing at all.
    expect(find.text('Continue as guest'), findsNothing);

    // The one exception is a throwaway door that exists in debug builds only,
    // labelled as a test, so a developer can walk every screen. It is gated on
    // `kDebugMode` and asserts again where it is used, so it cannot ship.
    expect(
      find.textContaining('guest'),
      kDebugMode ? findsOneWidget : findsNothing,
    );

    // Every remaining route leaves the user with something to sign back in
    // with, which is the whole point.
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('signing up needs a name, an address and six characters', (
    tester,
  ) async {
    await _pump(tester);

    // Three boxes on the sign-up form, in this order. The name is first
    // because it is the one the app speaks aloud — every manifestation opens
    // by saying it, and without one the writer falls back to "friend".
    Finder box(int index) => find.byType(TextField).at(index);
    const name = 0;
    const email = 1;
    const password = 2;

    expect(find.byType(TextField), findsNWidgets(3));
    expect(_armed(tester, 'Create account'), isFalse);

    // Everything but the name.
    await tester.enterText(box(email), 'sana@example.com');
    await tester.enterText(box(password), 'sixchars');
    await tester.pumpAndSettle();
    expect(_armed(tester, 'Create account'), isFalse);

    await tester.enterText(box(name), 'Sana');
    await tester.pumpAndSettle();
    expect(_armed(tester, 'Create account'), isTrue);

    // And the two that were already checked, still checked.
    await tester.enterText(box(email), 'not-an-email');
    await tester.pumpAndSettle();
    expect(_armed(tester, 'Create account'), isFalse);

    await tester.enterText(box(email), 'sana@example.com');
    await tester.enterText(box(password), 'short');
    await tester.pumpAndSettle();
    expect(_armed(tester, 'Create account'), isFalse);
  });

  testWidgets('logging back in does not ask for the name again', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.textContaining('Log in', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Your first name'), findsNothing);
  });

  testWidgets('the form switches between signing up and logging in', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Make an account'), findsOneWidget);
    await tester.tap(find.textContaining('Log in', findRichText: true));
    await tester.pumpAndSettle();

    // The way back for someone who signed out and is returning.
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });

  testWidgets('forgot password is only offered where it applies', (
    tester,
  ) async {
    await _pump(tester);

    // Nobody has forgotten the password of an account they are creating, and
    // sign-up is where this screen now opens.
    expect(find.text('Forgot password?'), findsNothing);

    await tester.tap(find.textContaining('Log in', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsOneWidget);
  });

  testWidgets('forgot password carries the typed address across', (
    tester,
  ) async {
    await _pump(tester);

    // Reachable only from the log-in form, so switch to it first.
    await tester.tap(find.textContaining('Log in', findRichText: true));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'sana@example.com');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    // Retyping an address you just typed is the smallest possible insult, and
    // the most avoidable.
    expect(find.text('sana@example.com'), findsOneWidget);
  });

  testWidgets('the upgrade route also opens on the sign-up form', (
    tester,
  ) async {
    await _pump(tester, asUpgrade: true);

    // Kept for the accounts made while the guest door was open. They still
    // exist, and this is how their stories move onto something with a password
    // rather than being stranded beside it.
    expect(find.text('Keep your stories safe'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
