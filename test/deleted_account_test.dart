import 'package:astra/services/admin_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// The countdown shown beside an account an admin has closed.
///
/// Worth pinning because it is the only thing on screen saying how much room
/// is left to undo a deletion, and an off-by-one there reads as a day that
/// does not exist.
void main() {
  DeletedAccount closed({required Duration until}) => DeletedAccount(
    uid: 'u1',
    email: 'someone@example.com',
    deletedAt: DateTime.now(),
    purgeAfter: DateTime.now().add(until),
  );

  test('a full week reads as seven days', () {
    expect(closed(until: const Duration(days: 7)).daysLeft, 7);
  });

  test('part of a day still counts as a day', () {
    // Rounded up on purpose: "0d" beside an account that still exists would
    // say the data is already gone when it is not.
    expect(closed(until: const Duration(hours: 5)).daysLeft, 1);
    expect(closed(until: const Duration(hours: 25)).daysLeft, 2);
  });

  test('past due reads as due, never as negative', () {
    expect(closed(until: const Duration(days: -3)).daysLeft, 0);
  });

  test('no date at all is treated as due rather than as forever', () {
    const orphan = DeletedAccount(uid: 'u1');
    expect(orphan.daysLeft, 0);
  });

  test('the overview parses what the server sends', () {
    final overview = AdminOverview.fromMap({
      'totalUsers': 2,
      'totalStories': 5,
      'subscribers': 1,
      'users': const [],
      'deleted': [
        {
          'uid': 'gone1',
          'email': 'gone@example.com',
          'name': 'Sana',
          'deletedAt': DateTime.now().toIso8601String(),
          'purgeAfter': DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String(),
        },
      ],
    });

    expect(overview.deleted, hasLength(1));
    expect(overview.deleted.single.email, 'gone@example.com');
    expect(overview.deleted.single.daysLeft, 7);
  });

  test('an overview with no deletions parses to an empty list', () {
    final overview = AdminOverview.fromMap({
      'totalUsers': 0,
      'totalStories': 0,
      'subscribers': 0,
      'users': const [],
    });

    expect(overview.deleted, isEmpty);
  });
}
