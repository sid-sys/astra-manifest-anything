import 'package:astra/providers.dart';
import 'package:astra/screens/paywall_screen.dart';
import 'package:astra/services/billing_service.dart';
import 'package:astra/theme/astra_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A billing service that answers only the one question this screen asks of
/// it: is there a store on this platform at all.
class _Billing extends BillingService {
  _Billing({required this.present});

  final bool present;

  @override
  bool get hasStore => present;

  @override
  Future<bool> get isAvailable async => present;

  @override
  Future<Map<String, StoreOffer>> loadOffers() async => const {};
}

/// What the paywall offers, and — more to the point — what it must never offer.
///
/// The screen can be left now. It could not be, and the reasoning was that a
/// paywall with an exit is a paywall nobody pays at; what it actually produced
/// was a dead end whose only escape was force-quitting the app, which then
/// dropped the user on Home for free because nothing there checked the
/// entitlement. The check now lives on Home, so this screen can afford a door.
///
/// What it must not have is any control that arrives at an entitlement by some
/// route other than paying. It has had two: a debug button that asked the
/// server for a real test subscription, and a debug web branch that dismissed
/// the screen outright. Both are gone, and the last test here is what notices
/// if either comes back.
Future<void> _pump(
  WidgetTester tester, {
  required bool store,
  bool size = true,
  bool pushed = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  // Tall by default so every button is built; the layout test sets its own.
  if (size) {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  const paywall = PaywallScreen(hard: true);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        billingServiceProvider.overrideWith(
          (ref) => _Billing(present: store),
        ),
      ],
      child: MaterialApp(
        theme: buildAstraTheme(),
        // Two different lives, and the difference is the point. Pushed, there
        // is a screen underneath and leaving means popping. As `home`, there is
        // nothing underneath at all — which is how the app shows it to an
        // account that has not paid.
        home: pushed
            ? Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<bool>(builder: (_) => paywall),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              )
            : paywall,
      ),
    ),
  );

  if (pushed) {
    await tester.tap(find.text('open'));
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pushed, it offers back — there is somewhere to go', (
    tester,
  ) async {
    await _pump(tester, store: false, pushed: true);

    // It used to be a cage, on the reasoning that a paywall with an exit is a
    // paywall nobody pays at. What that produced was a dead end whose only
    // escape was force-quitting, which then dropped the user on Home for free
    // because nothing there checked the entitlement. The lock moved to Home,
    // so this screen can afford a door.
    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    expect(find.text('Restore a purchase'), findsOneWidget);
  });

  testWidgets('as the root, it offers sign out and never a back button', (
    tester,
  ) async {
    await _pump(tester, store: false);

    // The bug this pins down: as the app's root there is nothing underneath to
    // pop to, and popping anyway empties the navigator and leaves a black
    // screen with only the phone's own buttons on it. That is what a
    // *successful payment* did — money taken, app blanked.
    expect(find.bySemanticsLabel('Back'), findsNothing);

    // And without back, something has to let a person who will not pay reach
    // another account. Sign out grants nothing: signing back in runs the same
    // check that put them here.
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Restore a purchase'), findsOneWidget);
  });

  testWidgets('the offer fits a small phone without clipping anything', (
    tester,
  ) async {
    // 375x667 — the smallest screen worth supporting, and shorter than the
    // laptop browser the sample cards were found sliced in half on.
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await _pump(tester, store: false, size: false);

    // The screen sized its samples by subtraction for a while: a Column with
    // everything fixed and one Expanded at the end, which gave the cards
    // whatever the plans had not taken and cut the second one off mid-word.
    // A RenderFlex overflow arrives here as an exception, so this is the whole
    // assertion.
    expect(tester.takeException(), isNull);

    // Pinned, not scrolled off with the rest of the offer.
    expect(find.text('Restore a purchase'), findsOneWidget);
  });

  testWidgets('nothing on the paywall grants a subscription by itself', (
    tester,
  ) async {
    await _pump(tester, store: true);

    // There was a debug-only button here that asked the server for a real
    // test subscription, and a debug-only web branch that dismissed the
    // screen without one. Both are gone. What is left must only ever be a
    // purchase, a restore, or leaving — never a way to arrive entitled.
    expect(find.textContaining('TEST'), findsNothing);
    expect(find.textContaining('DEBUG'), findsNothing);
    expect(find.text('Restore a purchase'), findsOneWidget);
  });
}
