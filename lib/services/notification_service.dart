import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/affirmation_taste.dart';
import '../models/intention.dart';
import 'affirmations.dart';

/// The daily affirmation, delivered as a notification.
///
/// Scheduled on the device rather than pushed from a server. That is a real
/// decision, not a shortcut: a push would need FCM tokens, a scheduled
/// function, and a per-user timezone the server would have to guess — for a
/// line of text the phone can already work out for itself. It also keeps
/// working with no network, costs nothing per user, and means the app is not
/// holding a push token for people who never wanted notifications.
///
/// The cost of that choice is that the text has to be scheduled in advance, so
/// this queues [_horizon] days at a time and tops the queue up whenever the app
/// opens. Someone who does not open the app for two weeks stops being
/// reminded — which is arguably correct, and is the honest limit of a
/// device-scheduled reminder.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  /// How many days of affirmations are queued at once.
  static const _horizon = 14;

  /// Android channel. Named for what it is, because this string is what the
  /// user sees in system settings when they go looking for the thing that
  /// woke their phone.
  static const _channel = AndroidNotificationChannel(
    'daily_affirmation',
    'Daily affirmation',
    description: 'One affirmation each morning, at the time you choose.',
    importance: Importance.defaultImportance,
  );

  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;

    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (error) {
      // A device whose zone we cannot read still gets reminders, just in UTC.
      // Better than no reminder at all, and better than crashing on launch.
      debugPrint('Astra: could not resolve timezone, using UTC — $error');
    }

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

    _ready = true;
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

  /// Replaces the queue with the next [_horizon] days of affirmations.
  ///
  /// Cancels first, so changing the time does not leave yesterday's schedule
  /// running alongside today's.
  Future<void> scheduleDaily({
    required int hour,
    required int minute,
    required Set<Intention> intentions,
    required AffirmationTaste taste,
  }) async {
    await _init();
    await cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    for (var day = 0; day < _horizon; day++) {
      var when = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      ).add(Duration(days: day));

      // Today's slot may already have passed; the first notification is then
      // tomorrow's rather than one that fires immediately on save.
      if (when.isBefore(now)) continue;

      final line = Affirmations.forDay(when, intentions, taste);

      await _plugin.zonedSchedule(
        id: day,
        title: 'Today’s affirmation',
        body: line,
        scheduledDate: when,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            // The line is the whole notification, and some run past one line.
            styleInformation: BigTextStyleInformation(line),
          ),
        ),
        // Inexact on purpose. Exact alarms need SCHEDULE_EXACT_ALARM, which
        // Play grants only to alarm clocks and calendars — and nobody needs an
        // affirmation delivered to the second.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }

  /// Whether the user has already granted permission, without asking again.
  Future<bool> get isPermitted async {
    await _init();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        false;
  }
}
