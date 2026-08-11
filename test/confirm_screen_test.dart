import 'package:astra/providers.dart';
import 'package:astra/screens/confirm_screen.dart';
import 'package:astra/theme/astra_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The guard on the two irreversible actions.
///
/// Worth a test rather than a look: the whole value of the typed confirmation
/// is that it is impossible to trigger by accident, and "impossible by
/// accident" is exactly the property a screenshot cannot demonstrate.
Future<Widget> _bootstrap(ConfirmKind kind) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      theme: buildAstraTheme(),
      home: ConfirmScreen(kind: kind),
    ),
  );
}

/// Whether the destructive button will do anything if tapped.
///
/// Asks the InkWell rather than the Semantics node: a disabled-looking button
/// that still fires is the failure this is guarding against, and only the tap
/// handler settles that.
bool _armed(WidgetTester tester, String label) {
  final button = tester.widget<InkWell>(
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first,
  );
  return button.onTap != null;
}

void main() {
  testWidgets('deleting stays locked until the word is typed', (tester) async {
    await tester.pumpWidget(await _bootstrap(ConfirmKind.deleteData));

    expect(_armed(tester, 'Delete everything'), isFalse);

    // Close, but not the word.
    await tester.enterText(find.byType(TextField), 'DELET');
    await tester.pumpAndSettle();
    expect(_armed(tester, 'Delete everything'), isFalse);

    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pumpAndSettle();
    expect(_armed(tester, 'Delete everything'), isTrue);
  });

  testWidgets('the typed word ignores case and stray spaces', (tester) async {
    await tester.pumpWidget(await _bootstrap(ConfirmKind.deleteData));

    // Someone who typed it on a phone keyboard meant it just as much.
    await tester.enterText(find.byType(TextField), ' delete ');
    await tester.pumpAndSettle();
    expect(_armed(tester, 'Delete everything'), isTrue);
  });

  testWidgets('logging out asks once and does not demand typing', (
    tester,
  ) async {
    await tester.pumpWidget(await _bootstrap(ConfirmKind.signOut));

    expect(find.byType(TextField), findsNothing);
    expect(_armed(tester, 'Log out'), isTrue);
  });

  testWidgets('logging out promises the library comes back', (tester) async {
    await tester.pumpWidget(await _bootstrap(ConfirmKind.signOut));

    // Only true because guest accounts are gone: every account now has
    // credentials to sign back in with, so this is a promise the app keeps.
    expect(find.textContaining('come back when you log in again'), findsOneWidget);
  });

  testWidgets('both screens offer a way out that keeps the data', (
    tester,
  ) async {
    for (final kind in ConfirmKind.values) {
      await tester.pumpWidget(await _bootstrap(kind));
      expect(find.text('Keep my data'), findsOneWidget);
    }
  });
}
