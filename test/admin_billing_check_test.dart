import 'package:astra/admin/admin_billing_check_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every verdict has plain words and the right mood', () {
    expect(describeVerdict({'verdict': 'paid'}).good, isTrue);
    expect(describeVerdict({'verdict': 'trial'}).good, isTrue);
    expect(describeVerdict({'verdict': 'cancelled'}).good, isTrue);
    expect(describeVerdict({'verdict': 'card_failed'}).good, isFalse);

    final waiting = describeVerdict({'verdict': 'no_charge_yet', 'daysSinceTrialEnded': 8});
    expect(waiting.good, isFalse);
    expect(waiting.why, contains('8 days ago'));
    expect(waiting.why, contains('Order management'));

    final broken = describeVerdict({'verdict': 'unreadable', 'error': 'PERMISSION_DENIED'});
    expect(broken.good, isFalse);
    expect(broken.why, contains('PERMISSION_DENIED'));
  });
}
