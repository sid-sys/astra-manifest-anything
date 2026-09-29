import 'dart:async';

import 'dart:io' show Platform;

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

  /// Whether this build can push at all.
  ///
  /// Android only. The web build has no notification plugin registered, so
  /// every call threw `MissingPluginException` and took the surrounding
  /// widget down with it — reminders are an Android feature and the web build
  /// exists to look at screens, not to be notified by them. iOS will need its
  /// own APNs setup before it can be added here.
  bool get _supported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Null when push is unavailable — on the web, or when Firebase never
  /// started. The app still runs; it just has no reminders. Read lazily
  /// rather than in the constructor because the provider is built before
  /// anyone has checked whether Firebase came up.
  FirebaseMessaging? get _push {
    if (messaging != null) return messaging;
    if (!_supported) return null;
    try {
      return FirebaseMessaging.instance;
    } catch (error) {
      debugPrint('Maya: messaging unavailable — $error');
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

  /// Announcements from us, on their own channel.
  ///
  /// Separate from the affirmation channel on purpose. Android channels are
  /// the user's controls: somebody who wants their morning line but not news
  /// about the app has to be able to switch one off and keep the other, and
  /// that only works if they arrive separately. Sending an announcement down
  /// the affirmation channel would be spending a permission that was given for
  /// something else.
  ///
  /// The id is repeated in `BROADCAST_CHANNEL` in the Cloud Function.
  static const _announcements = AndroidNotificationChannel(
    'announcements',
    'News about the app',
    description: 'Occasional word from us when something changes.',
    importance: Importance.defaultImportance,
  );

  bool _ready = false;

  /// Called with a broadcast id when the user opens one of our announcements.
  ///
  /// Set by whoever owns the server call, so this class keeps knowing nothing
  /// about Cloud Functions — it owns permission, channels and the token, and
  /// adding a fourth job to it is how a service becomes a junk drawer.
  void Function(String broadcastId)? onBroadcastOpened;

  Future<void> _init() async {
    if (_ready || !_supported) return;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      // A tap on a notification this app drew itself, rather than one Android
      // drew from the tray. Same event to the user, two different callbacks.
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) _opened(payload);
      },
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.createNotificationChannel(_channel);
    await android?.createNotificationChannel(_announcements);

    // A push that lands while the user is looking at the app is swallowed by
    // Android — the system tray is for things you are not already holding. It
    // is still worth showing, so it gets drawn locally instead.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // Tapped while the app was in the background, and tapped on a phone where
    // the app was not running at all. Two callbacks because Android delivers
    // them at different moments, and missing the second one loses every open
    // from a cold start — which is most of them.
    FirebaseMessaging.onMessageOpenedApp.listen(_fromTap);
    unawaited(
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) _fromTap(message);
      }),
    );

    _ready = true;
  }

  void _fromTap(RemoteMessage message) {
    final id = message.data['broadcastId'];
    if (id is String && id.isNotEmpty) _opened(id);
  }

  void _opened(String broadcastId) {
    final report = onBroadcastOpened;
    if (report != null) report(broadcastId);
  }

  Future<void> _showForeground(RemoteMessage message) async {
    final body = message.notification?.body ?? message.data['line'];
    if (body == null || body.isEmpty) return;

    // An announcement and a daily affirmation are drawn on their own channels
    // and given their own ids, so one never replaces the other in the tray.
    final broadcastId = message.data['broadcastId'] as String?;
    final isBroadcast = message.data['type'] == 'broadcast';
    final channel = isBroadcast ? _announcements : _channel;

    // An announcement may arrive with no title, and should then be drawn with
    // none — Android puts the app name in the header either way. Only the
    // affirmation falls back to a title, because it always had one.
    final title = message.notification?.title;

    await _plugin.show(
      id: isBroadcast ? 1 : 0,
      title: isBroadcast ? title : (title ?? 'Today’s affirmation'),
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
      // Comes back as the payload when this one is tapped.
      payload: isBroadcast ? broadcastId : null,
    );
  }

  /// Asks for permission to post notifications.
  ///
  /// Android 13 and up require this at runtime. Asked when the user turns
  /// reminders on rather than at launch — a permission prompt in the first ten
  /// seconds of an app is the one everybody denies.
  Future<bool> requestPermission() async {
    if (!_supported) return false;
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
    if (!_supported) return (token: null, zone: 'UTC');
    await _init();

    var zone = 'UTC';
    try {
      zone = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (error) {
      debugPrint('Maya: could not resolve timezone — $error');
    }

    try {
      return (token: await _push?.getToken(), zone: zone);
    } catch (error) {
      debugPrint('Maya: no push token — $error');
      return (token: null, zone: zone);
    }
  }

  /// Stops this device being pushed to.
  ///
  /// Deletes the token rather than only clearing it from the profile: a token
  /// that still exists is a token something else could send to, and "off"
  /// should mean off at the device, not off by convention on the server.
  Future<void> unregister() async {
    if (!_supported) return;
    try {
      await _push?.deleteToken();
    } catch (error) {
      debugPrint('Maya: could not delete push token — $error');
    }
    try {
      await _plugin.cancelAll();
    } catch (error) {
      debugPrint('Maya: could not clear notifications — $error');
    }
  }

  /// Fires when Android rotates the token underneath us, which it does on
  /// reinstall, restore, and occasionally for its own reasons. A rotated token
  /// that never reaches the server is a user whose reminders silently stop.
  Stream<String> get tokenRefreshes {
    if (!_supported) return const Stream<String>.empty();
    try {
      return _push?.onTokenRefresh ?? const Stream<String>.empty();
    } catch (error) {
      debugPrint('Maya: no token refresh stream — $error');
      return const Stream<String>.empty();
    }
  }
}
