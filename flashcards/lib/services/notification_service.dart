import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const _notificationId = 0;
const _channelId = 'daily_reminder';
const _channelName = 'Daily Reminder';

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize({void Function(String? payload)? onTap}) async {
    if (_initialized) return;
    try {
      tz.initializeTimeZones();
      if (Platform.isAndroid || Platform.isIOS) {
        try {
          final tzInfo = await FlutterTimezone.getLocalTimezone();
          tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
        } catch (_) {}
      }

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notify'),
          iOS: DarwinInitializationSettings(),
          macOS: DarwinInitializationSettings(),
          linux: LinuxInitializationSettings(defaultActionName: 'Show'),
        ),
        onDidReceiveNotificationResponse: (details) {
          onTap?.call(details.payload);
        },
      );
      _initialized = true;
    } catch (_) {
      // Platform channel not available in tests or unsupported platforms.
    }
  }

  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final plugin = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await plugin?.requestNotificationsPermission() ?? false;
      }
      if (Platform.isIOS) {
        final plugin = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await plugin?.requestPermissions(alert: true, sound: true) ??
            false;
      }
    } catch (_) {}
    return true;
  }

  Future<void> scheduleDailyReminder({
    required TimeOfDay time,
    required String message,
  }) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    try {
      await _plugin.zonedSchedule(
        id: _notificationId,
        title: 'Deep Flashcard',
        body: message,
        scheduledDate: _nextInstanceOf(time.hour, time.minute),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            icon: 'ic_stat_notify',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }

  Future<void> cancelAll() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
