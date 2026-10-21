import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts what people do in the app, on this phone.
///
/// The admin dashboard reads its events from the server (`trackEvent`); this
/// keeps the same counts on the phone as well. The server-side `trackEvent` function already stores counts per
/// account for the real admin numbers.
///
/// **Next step:** send each call here to Firestore, under
/// `users/{uid}/events/{autoId}` as `{type, detail, time}`, with a rule that
/// lets only the owner create them. Then `RealAdminRepository` can read a real
/// timeline instead of rebuilding one.
class AnalyticsService {
  const AnalyticsService._();

  static const _countsKey = 'analytics_counts';

  /// Records one event. Never throws: a counter must not break the screen that
  /// made it.
  static Future<void> log(String type, {String detail = ''}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final counts = _read(prefs);
      counts[type] = (counts[type] ?? 0) + 1;
      await prefs.setString(_countsKey, jsonEncode(counts));
    } catch (error) {
      debugPrint('Mayow: could not count $type — $error');
    }
  }

  /// How many times each event has happened on this phone.
  static Future<Map<String, int>> counts() async =>
      _read(await SharedPreferences.getInstance());

  static Map<String, int> _read(SharedPreferences prefs) {
    final raw = prefs.getString(_countsKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );
  }

  /// The events worth counting on the phone: the funnel and the money steps.
  /// Null for anything else.
  static String? typeFor(String event, {String? detail}) => switch (event) {
    'app_open' ||
    'onboarding_start' ||
    'onboarding_done' ||
    'wish_typed' ||
    'paywall_view' ||
    'subscribe_tap' ||
    'purchase_ok' ||
    'purchase_cancelled' ||
    'purchase_failed' => event,
    'generate_ok' =>
      detail == 'affirmations' ? 'affirmations_made' : 'manifestation_made',
    _ => null,
  };
}
