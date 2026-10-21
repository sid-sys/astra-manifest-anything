import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_build.dart';

/// Tells the server, once a day, that this phone still has the app.
///
/// The admin panel's install and uninstall chart is built from one record per
/// phone. This is where that record starts:
///
/// - **A random install id**, made the first time and kept on the phone, so a
///   phone counts once however many accounts sign in on it. Reinstalling the app
///   wipes it, so a reinstall is a new phone record on its real install day.
/// - **The install time Android reports for the app**, so a phone that only
///   updated the app keeps its real install day.
/// - **The push address**, which is how the server later finds out the app was
///   removed (Google stops accepting it).
///
/// It goes to a Cloud Function, never to the database directly: the server
/// checks the caller and is the only thing allowed to write the record.
class DeviceService {
  DeviceService({FirebaseFunctions? functions}) : _injected = functions;

  final FirebaseFunctions? _injected;

  FirebaseFunctions get _functions =>
      _injected ?? FirebaseFunctions.instanceFor(region: 'asia-south1');

  static const _idKey = 'install_id';
  static const _dayKey = 'device_reported_day';
  static const _tokenKey = 'device_reported_token';

  /// Reports at most once a day, or sooner if the push address changed.
  /// Never throws: a missed report is a number slightly low, not a bug.
  Future<void> reportToday({String? pushToken}) async {
    if (kIsWeb) return; // There is no install to count in a browser.

    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now().toUtc();
      final today = now.toIso8601String().substring(0, 10);

      final sameDay = prefs.getString(_dayKey) == today;
      final sameToken = prefs.getString(_tokenKey) == (pushToken ?? '');
      if (sameDay && sameToken) return;

      var id = prefs.getString(_idKey);
      if (id == null) {
        id = _randomId();
        await prefs.setString(_idKey, id);
      }

      final info = await PackageInfo.fromPlatform();
      await _functions.httpsCallable('reportDevice').call<Object?>({
        'installId': id,
        'installedAt': (info.installTime ?? now).toUtc().toIso8601String(),
        'platform':
            defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
        'appBuild': kAppBuild,
        'fcmToken': ?pushToken,
      });

      await prefs.setString(_dayKey, today);
      await prefs.setString(_tokenKey, pushToken ?? '');
    } catch (error) {
      debugPrint('Mayow: could not report this device — $error');
    }
  }

  static String _randomId() {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(28, (_) => alphabet[rng.nextInt(alphabet.length)])
        .join();
  }
}
