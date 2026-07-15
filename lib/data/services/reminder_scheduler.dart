import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/time_session.dart';
import '../../domain/services/forgotten_timer.dart';

/// Schedules the forgotten-timer reminder. Abstract so tests and non-Android
/// platforms use a no-op.
abstract interface class ReminderScheduler {
  Future<void> scheduleFor(
    TimeSession session,
    ForgottenTimerSettings settings, {
    String contextLabel,
  });

  Future<void> cancel();

  /// Ensures exact alarms are permitted (opens system settings if needed);
  /// returns whether they are now available. See [AndroidReminderScheduler].
  Future<bool> ensureExactAlarms();
}

class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> scheduleFor(
    TimeSession session,
    ForgottenTimerSettings settings, {
    String contextLabel = '',
  }) async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> ensureExactAlarms() async => true;
}

/// Android implementation: a SYSTEM alarm (exact-allow-while-idle), so the
/// reminder fires at start+threshold even in deep Doze or under aggressive
/// OEM throttling — independent of any Dart isolate being alive.
class AndroidReminderScheduler implements ReminderScheduler {
  AndroidReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _notificationId = 1001;
  static const _channelId = 'timedock_reminder';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  bool _askedExactAlarms = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    await _android?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      'Przypomnienia',
      description: 'Ostrzeżenie o długo działającym timerze',
      importance: Importance.high,
    ));
    _initialized = true;
  }

  /// Ensures exact alarms are permitted; without them zonedSchedule falls back
  /// to inexact, which OEMs (ColorOS etc.) defer until the device wakes — so
  /// the reminder only shows when the app is reopened. Opens the system
  /// "Alarms & reminders" screen once if needed.
  @override
  Future<bool> ensureExactAlarms() async {
    await _ensureInitialized();
    final canExact = await _android?.canScheduleExactNotifications() ?? true;
    if (canExact) return true;
    if (!_askedExactAlarms) {
      _askedExactAlarms = true;
      await _android?.requestExactAlarmsPermission();
      return await _android?.canScheduleExactNotifications() ?? false;
    }
    return false;
  }

  /// (Re)schedules the reminder for [session] according to [settings];
  /// cancels any previous one first. No-op when reminders are disabled or
  /// the fire time already passed (the in-app trim dialog covers that case).
  @override
  Future<void> scheduleFor(
    TimeSession session,
    ForgottenTimerSettings settings, {
    String contextLabel = '',
  }) async {
    await _ensureInitialized();
    await _plugin.cancel(_notificationId);
    if (!settings.enabled) return;

    final fireAtUtc = session.startUtc.add(settings.threshold);
    if (!fireAtUtc.isAfter(DateTime.now().toUtc())) return;

    // Prompt for exact-alarm permission the first time we schedule, so the
    // reminder fires in Doze instead of being deferred until the app wakes.
    await ensureExactAlarms();

    final label = contextLabel.isEmpty ? 'bieżącym zadaniem' : contextLabel;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'Przypomnienia',
        channelDescription: 'Ostrzeżenie o długo działającym timerze',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final body = 'Timer nad $label działa dłużej niż zwykle. '
        'Otwórz TimeDock, aby zatrzymać lub przyciąć sesję.';
    final fireAt = tz.TZDateTime.from(fireAtUtc, tz.UTC);

    try {
      await _plugin.zonedSchedule(
        _notificationId,
        'Nadal pracujesz?',
        body,
        fireAt,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on PlatformException {
      // Exact alarms unavailable (permission revoked): degrade to inexact,
      // which may be delayed by Doze but still fires.
      await _plugin.zonedSchedule(
        _notificationId,
        'Nadal pracujesz?',
        body,
        fireAt,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  @override
  Future<void> cancel() async {
    await _ensureInitialized();
    await _plugin.cancel(_notificationId);
  }
}
