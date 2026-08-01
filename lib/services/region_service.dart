import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../models/plan.dart';

/// Where the user is, for pricing purposes.
///
/// Read from the device locale (`en_IN` → `IN`), falling back to `US`. There
/// is no manual override: asking someone to pick their own currency is asking
/// them to do the app's job, and the locale is right for almost everyone.
///
/// Deliberately does not use IP geolocation: it needs no network, no extra
/// permission, and no personal data leaves the device.
class RegionService {
  const RegionService();

  String get countryCode => _deviceCountryCode();

  String get currencyCode => PricingCatalog.currencyForCountry(countryCode);

  List<Plan> get plans => PricingCatalog.plansForCountry(countryCode);

  bool get isIndia => countryCode == 'IN';

  static String _deviceCountryCode() {
    final fromLocale = ui.PlatformDispatcher.instance.locale.countryCode;
    if (fromLocale != null && fromLocale.isNotEmpty) {
      return fromLocale.toUpperCase();
    }

    if (!kIsWeb) {
      // e.g. "en_IN.UTF-8" on Android/desktop.
      final parts = Platform.localeName.split(RegExp(r'[_-]'));
      if (parts.length > 1) {
        final region = parts[1].split('.').first;
        if (region.length == 2) return region.toUpperCase();
      }
    }

    return 'US';
  }
}
