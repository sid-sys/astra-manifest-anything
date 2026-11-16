import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import '../demo/demo_data.dart';

/// Which store sells Mayow Plus on this phone, in words for the screen.
///
/// The paywall tells people where to cancel. Saying "Google Play" to someone on
/// an iPhone is wrong, and Apple rejects an app that does it.
///
/// The demo build can pretend to be an iPhone with `?store=apple`, which is how
/// the App Store screenshots of the paywall are taken.
bool get sellsThroughAppStore {
  if (Demo.on && Uri.base.queryParameters['store'] == 'apple') return true;
  return !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
}

/// "Google Play" or "the App Store", for the middle of a sentence.
String get storeName => sellsThroughAppStore ? 'the App Store' : 'Google Play';

/// The same, for the start of a sentence.
String get storeNameCap => sellsThroughAppStore ? 'The App Store' : 'Google Play';
