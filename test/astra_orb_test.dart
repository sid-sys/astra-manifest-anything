import 'package:astra/widgets/astra_orb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The orb draws, in both states, at the size it was asked for.
///
/// This file was written because the orb crashed: it ran two animations off a
/// ticker that allows one, and it threw in `initState`. The orb sits on the
/// waiting screen, so every manifestation and every affirmation died on a red
/// screen before a word was written, and nothing caught it.
///
/// The animation is a file now rather than a painting, so there is no ticker
/// left to get wrong. What is worth pinning is what replaced it: that both
/// assets load, that the paused state is the still and not the moving one, and
/// that neither throws.
void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  String assetOf(WidgetTester tester) {
    final image = tester.widget<Image>(find.byType(Image));
    return (image.image as AssetImage).assetName;
  }

  testWidgets('the moving orb builds and keeps running', (tester) async {
    await tester.pumpWidget(host(const AstraOrb()));
    expect(tester.takeException(), isNull);
    expect(assetOf(tester), 'assets/brand/orb.webp');

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('parked shows the still, not the animation', (tester) async {
    await tester.pumpWidget(host(const AstraOrb(spinning: false)));
    expect(tester.takeException(), isNull);
    expect(assetOf(tester), 'assets/brand/orb_still.png');

    // Nothing is running, so this settles. The animation never would.
    await tester.pumpAndSettle();
  });

  testWidgets('takes the size it is given', (tester) async {
    await tester.pumpWidget(host(const AstraOrb(size: 132)));
    await tester.pump();

    final box = tester.getSize(find.byType(AstraOrb));
    expect(box, const Size(132, 132));
  });
}
