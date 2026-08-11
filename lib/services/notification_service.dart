import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// The daily affirmation, delivered as a notification.
///
/// Pushed from the server, not scheduled on the device. The first version of
/// this scheduled fourteen days of curated lines locally, which worked offline
/// and cost nothing — but a locally scheduled notification can only ever say
/// something the app already shipped. The lines are now written per user, from
/// their own areas of life and their own words about what they want, which is
/// work only a server holding an API key can do.
///
/// The trade is honest and worth naming: this needs a network at the moment of
/// sending, and a push into a phone that has been offline all night arrives
/// when it reconnects rather than at eight sharp. In exchange the affirmation
/// is about the user's life instead of a stranger's.
///
/// This class owns three things and no more: permission, the channel, and the
/// token. The text arrives from [dailyAffirmation] in `functions/index.js`.
class NotificationService {
  NotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    this.messaging,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// Injected only by tests. Null in the app, where [_push] reads the singleton.
  final FirebaseMessaging? messaging;

  /// Null when Firebase never started — the app still runs, it just has no
  /// push. Read lazily rather than in the constructor because the provider is
  /// built before anyone has checked whether Firebase came up.
  FirebaseMessaging? get _push {
    if (messaging != null) return messaging;
    try {
      return FirebaseMessaging.instance;
    } catch (error) {
      debugPrint('Astra: messaging unavailable — $error');
      return null;
    }
  }

  /// Android channel. This id is repeated in the Cloud Function that sends the
  /// message; a mismatch files the notification under a default channel the
  /// user never agreed to, at a priority they never chose.
  static const _channel = AndroidNotificationChannel(
    'daily_affirmation',
    'Daily affirmation',
    description: 'One affirmation each morning, at the time you choose.',
    importance: Importance.defaultImportance,
  );

  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // A push that lands while the user is looking at the app is swallowed by
    // Android — the system tray is for things you are not already holding. It
    // is still worth showing, so it gets drawn locally instead.
    FirebaseMessaging.onMessage.listen(_showForeground);

    _ready = true;
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final body = message.notification?.body ?? message.data['line'];
    if (body == null || body.isEmpty) return;

    await _plugin.show(
      id: 0,
      title: message.notification?.title ?? 'Today’s affirmation',
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  /// Asks for permission to post notifications.
  ///
  /// Android 13 and up require this at runtime. Asked when the user turns
  /// reminders on rather than at launch — a permission prompt in the first ten
  /// seconds of an app is the one everybody denies.
  Future<bool> requestPermission() async {
    await _init();

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    return await android?.requestNotificationsPermission() ?? false;
  }

  /// The address this phone can be pushed to, and the zone it lives in.
  ///
  /// Both are needed together and neither is useful alone: the token says where
  /// to send, the IANA zone says when. An offset would have been simpler and
  /// wrong twice a year — the point of the feature is arriving in the morning,
  /// and a stored `+05:30` does not follow anyone across daylight saving.
  ///
  /// Returns nulls rather than throwing when push is unavailable. A user with
  /// no Play Services still gets the whole app; they just get no reminder.
  Future<({String? token, String zone})> register() async {
    await _init();

    var zone = 'UTC';
    try {
      zone = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (error) {
      debugPrint('Astra: could not resolve timezone — $error');
    }

    try {
      return (token: await _push?.getToken(), zone: zone);
    } catch (error) {
      debugPrint('Astra: no push token — $error');
      return (token: null, zone: zone);
    }
  }

  /// Stops this device being pushed to.
  ///
  /// Deletes the token rather than only clearing it from the profile: a token
  /// that still exists is a token something else could send to, and "off"
  /// should mean off at the device, not off by convention on the server.
  Future<void> unregister() async {
    try {
      await _push?.deleteToken();
    } catch (error) {
      debugPrint('Astra: could not delete push token — $error');
    }
    await _plugin.cancelAll();
  }

  /// Fires when Android rotates the token underneath us, which it does on
  /// reinstall, restore, and occasionally for its own reasons. A rotated token
  /// that never reaches the server is a user whose reminders silently stop.
  Stream<String> get tokenRefreshes =>
      _push?.onTokenRefresh ?? const Stream<String>.empty();
}
