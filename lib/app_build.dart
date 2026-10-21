/// The build number of this binary. Keep it equal to the number after the `+`
/// in `pubspec.yaml` (`test/app_build_test.dart` fails when they differ).
///
/// It is written to the user's profile as `appBuild` so the admin panel can
/// tell who has the new app and who is still on an old one.
const int kAppBuild = 48;

/// The first build that puts new accounts behind the paywall.
///
/// An account whose profile carries a `signupBuild` at or above this was
/// created by a build that sells the free trial first, and cannot reach the
/// app without it. Accounts created before that have no `signupBuild`, and
/// are left exactly as they were.
const int kGateFromBuild = 40;
