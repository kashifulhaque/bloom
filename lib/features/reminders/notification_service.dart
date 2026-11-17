/// Schedules reminder notifications on Android with
/// `flutter_local_notifications`.
///
/// The web build never calls the plugin: every entry point returns early
/// when `kIsWeb` is true, and the in-app `DueRemindersBanner` covers the web.
///
/// Notifications are one-shot alarms for the next 14 days. They are
/// recomputed whenever reminder or birth control settings change and once
/// per app session (from the Today banner), so predictions stay current.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/store.dart';
import 'contraception_model.dart';
import 'reminder_model.dart';
import 'scheduler.dart';

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _syncedThisSession = false;

  /// Android allows about 500 pending alarms per app; stay well below that.
  static const _maxScheduled = 120;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _init() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _initialized = true;
  }

  /// Asks for notification permission (Android 13+). Returns false when denied.
  static Future<bool> requestPermission() async {
    if (!supported) return false;
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Runs [sync] once per app session.
  static Future<void> syncOnce(AppStore store) async {
    if (_syncedThisSession) return;
    _syncedThisSession = true;
    await sync(store);
  }

  /// Cancels every pending reminder and schedules the next occurrences.
  static Future<void> sync(AppStore store) async {
    if (!supported) return;
    try {
      await _init();
      await _plugin.cancelAll();
      final now = DateTime.now();
      final occurrences = computeOccurrences(
        settings: ReminderSettings.of(store),
        contraception: Contraception.of(store),
        engine: store.engine,
        goal: store.profile.goal,
        now: now,
      ).where((o) => o.when.isAfter(now)).take(_maxScheduled).toList();
      if (occurrences.isEmpty) return;

      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final exact = await android?.canScheduleExactNotifications() ?? false;
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'bloom_reminders',
          'Reminders',
          channelDescription: 'Cycle, birth control, and wellness reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      for (var i = 0; i < occurrences.length; i++) {
        final o = occurrences[i];
        final (title, body) = notificationText(o, store.profile.notificationPrivacy);
        await _plugin.zonedSchedule(
          id: 1000 + i,
          // UTC instants avoid needing the device's IANA zone name.
          scheduledDate: tz.TZDateTime.from(o.when, tz.UTC),
          notificationDetails: details,
          androidScheduleMode:
              exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
          title: title,
          body: body,
        );
      }
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }
}
