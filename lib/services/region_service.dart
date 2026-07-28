import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import '../models/plan.dart';

/// Where the user is, for pricing purposes.
///
/// Resolution order:
///   1. an override the user picked in Settings (respects VPN/expat cases),
///   2. the device locale's country (`en_IN` → `IN`),
///   3. `US` as the last resort.
///
/// Deliberately does not use IP geolocation: it needs no network, no extra
/// permission, and no personal data leaves the device.
class RegionService {
  RegionService({String? overrideCountryCode})
    : _override = overrideCountryCode?.toUpperCase();

  final String? _override;

  String get countryCode => _override ?? _deviceCountryCode();

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
