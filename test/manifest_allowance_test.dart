import 'package:astra/models/manifestation.dart';
import 'package:astra/models/plan.dart';
import 'package:astra/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// How many manifestations are left, and what the screen says about it.
///
/// This is the number the Continue button is greyed out by, so it is worth
/// pinning. It used to count the *library* — every story ever written — which
/// meant a subscriber with a year of old stories opened the app already out of
/// allowance, and somebody with an empty library was shown a full one they had
/// not paid for. Neither number had anything to do with what they could write.
Manifestation _made(DateTime when) => Manifestation(
  id: when.toIso8601String(),
  dream: 'I want a place of my own',
  script: '…',
  duration: const Duration(minutes: 4),
  createdAt: when,
);

ProviderContainer _container({
  required bool subscribed,
  required List<Manifestation> made,
}) {
  final container = ProviderContainer(
    overrides: [
      isSubscribedProvider.overrideWithValue(subscribed),
      manifestationsProvider.overrideWith((ref) async => made),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  final now = DateTime.now();
  final thisMonth = DateTime(now.year, now.month, 2, 9);
  final lastMonth = DateTime(now.year, now.month).subtract(
    const Duration(days: 3),
  );

  test('nobody unsubscribed may write one', () {
    final container = _container(subscribed: false, made: const []);
    expect(container.read(manifestsLeftProvider), 0);
    expect(container.read(usageProvider).plan, 'Free');
  });

  test('a subscriber starts the month with the full allowance', () async {
    final container = _container(subscribed: true, made: const []);
    await container.read(manifestationsProvider.future);

    expect(container.read(manifestsLeftProvider), PricingCatalog.manifestMonthly);
    expect(container.read(usageProvider).plan, 'Mayow Plus');
  });

  test('last month does not count against this month', () async {
    final container = _container(
      subscribed: true,
      made: [_made(lastMonth), _made(lastMonth), _made(thisMonth)],
    );
    await container.read(manifestationsProvider.future);

    // One written this month, whatever the library holds from before it.
    expect(container.read(usageProvider).used, 1);
    expect(
      container.read(manifestsLeftProvider),
      PricingCatalog.manifestMonthly - 1,
    );
  });

  test('a spent month leaves nothing, and never goes negative', () async {
    final container = _container(
      subscribed: true,
      made: List.generate(
        PricingCatalog.manifestMonthly + 3,
        (_) => _made(thisMonth),
      ),
    );
    await container.read(manifestationsProvider.future);

    expect(container.read(manifestsLeftProvider), 0);
    expect(container.read(usageProvider).detail, contains('affirmations'));
  });
}
