import 'admin_config.dart';
import 'admin_models.dart';

/// Why an account should be left out of the numbers, or null for a real person.
///
/// The rules come from [AdminConfig]; the first one that fits wins. A rule that
/// might hit a real person must not be added here: show its reason on the row
/// instead of hiding silently.
String? hiddenReason(AdminUser user) {
  final email = user.email.trim().toLowerCase();
  final name = user.name.trim().toLowerCase();

  if (email == AdminConfig.adminEmail.toLowerCase()) return 'Your own account';

  if (AdminConfig.reviewEmails.any((e) => e.toLowerCase() == email)) {
    return 'Play review login';
  }

  if (AdminConfig.testRobotDomains.any((d) => email.endsWith('@${d.toLowerCase()}'))) {
    return 'Google test robot';
  }

  // A robot sign-up: the name is the review login's own email address.
  if (AdminConfig.reviewEmails.any((e) => e.toLowerCase() == name)) {
    return 'Play review robot';
  }

  if (AdminConfig.automatedEmailPatterns.any((p) => p.hasMatch(email))) {
    return 'Automated test';
  }

  if (user.testPurchase) return 'Test purchase';

  final seconds = user.onboardingSeconds;
  if (seconds != null && seconds < AdminConfig.minOnboardingSeconds) {
    return 'Looks like a robot';
  }

  return null;
}

/// Splits everybody into the people to count and the accounts left out, each of
/// those with the reason.
({List<AdminUser> visible, List<HiddenAccount> hidden}) splitUsers(
  List<AdminUser> users,
) {
  final visible = <AdminUser>[];
  final hidden = <HiddenAccount>[];
  for (final user in users) {
    final reason = hiddenReason(user);
    if (reason == null) {
      visible.add(user);
    } else {
      hidden.add(HiddenAccount(user, reason));
    }
  }
  return (visible: visible, hidden: hidden);
}
