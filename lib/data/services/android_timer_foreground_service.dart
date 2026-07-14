import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/time_session.dart';
import '../../domain/services/timer_foreground_service.dart';

/// Android implementation of [TimerForegroundService] backed by
/// flutter_foreground_task. Shows an ongoing notification with a live counter
/// and a STOP action while a timer runs.
///
/// The counter is rendered inside the service isolate ([TimerTaskHandler]) so
/// it keeps ticking with the app backgrounded. STOP is bridged to the main
/// isolate (see [main]) which performs the actual stop through the database,
/// so Riverpod streams update normally. The timer's correctness never depends
/// on this service — the running session row remains the source of truth.
class AndroidTimerForegroundService implements TimerForegroundService {
  bool _initialized = false;

  void _ensureInitialized() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'timedock_timer',
        channelName: 'Aktywny timer',
        channelDescription: 'Pokazuje działający pomiar czasu',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _initialized = true;
  }

  String _title(String label) =>
      label.isEmpty ? 'TimeDock — pomiar' : label;

  @override
  Future<void> show(TimeSession session, String contextLabel) async {
    _ensureInitialized();
    final startMillis = session.startUtc.millisecondsSinceEpoch;
    // Shared with the service isolate for cold-start rendering.
    await FlutterForegroundTask.saveData(key: 'startMillis', value: startMillis);
    await FlutterForegroundTask.saveData(key: 'label', value: contextLabel);

    if (await FlutterForegroundTask.isRunningService) {
      // Context/start may have changed (switch project, new session).
      FlutterForegroundTask.sendDataToTask(
          {'startMillis': startMillis, 'label': contextLabel});
      await FlutterForegroundTask.updateService(
        notificationTitle: _title(contextLabel),
      );
    } else {
      final permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
      await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: _title(contextLabel),
        notificationText: '0:00:00',
        notificationButtons: const [
          NotificationButton(id: 'stop', text: 'STOP'),
        ],
        callback: startTimerCallback,
      );
    }
  }

  @override
  Future<void> hide() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

/// Entry point of the service isolate. Must be top-level and kept alive by the
/// VM, hence the entry-point pragma.
@pragma('vm:entry-point')
void startTimerCallback() {
  FlutterForegroundTask.setTaskHandler(TimerTaskHandler());
}

/// Runs in the service isolate: renders the live counter into the ongoing
/// notification, fires the forgotten-timer reminder, and forwards the STOP
/// button to the main isolate.
class TimerTaskHandler extends TaskHandler {
  static const _reminderChannelId = 'timedock_reminder';
  static const _reminderNotificationId = 1001;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  int _startMillis = DateTime.now().millisecondsSinceEpoch;
  String _label = '';

  bool _reminderEnabled = true;
  int _reminderThresholdMillis = const Duration(hours: 4).inMilliseconds;
  bool _reminderShown = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _startMillis =
        await FlutterForegroundTask.getData<int>(key: 'startMillis') ??
            _startMillis;
    _label = await FlutterForegroundTask.getData<String>(key: 'label') ?? '';
    await _initLocalNotifications();
    await _loadReminderSettings();
    _render();
  }

  Future<void> _initLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _localNotifications.initialize(settings);
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _reminderChannelId,
          'Przypomnienia',
          description: 'Ostrzeżenie o długo działającym timerze',
          importance: Importance.high,
        ));
  }

  /// Reads the user's forgotten-timer settings straight from SharedPreferences
  /// (written by the main isolate's settings controller).
  Future<void> _loadReminderSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    _reminderEnabled = prefs.getBool('forgotten_timer_enabled') ?? true;
    final hours = prefs.getInt('forgotten_timer_threshold_hours') ?? 4;
    _reminderThresholdMillis = Duration(hours: hours).inMilliseconds;
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final start = data['startMillis'];
      if (start is num && start.toInt() != _startMillis) {
        _startMillis = start.toInt();
        _reminderShown = false; // new session → reminder can fire again
      }
      final label = data['label'];
      if (label is String) _label = label;
      _render();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _render();
    _maybeRemind();
  }

  void _render() {
    final elapsed = DateTime.now().millisecondsSinceEpoch - _startMillis;
    FlutterForegroundTask.updateService(
      notificationTitle: _label.isEmpty ? 'TimeDock — pomiar' : _label,
      notificationText: _formatElapsed(elapsed < 0 ? 0 : elapsed),
    );
  }

  void _maybeRemind() {
    if (!_reminderEnabled || _reminderShown) return;
    final elapsed = DateTime.now().millisecondsSinceEpoch - _startMillis;
    if (elapsed < _reminderThresholdMillis) return;
    _reminderShown = true;
    final label = _label.isEmpty ? 'bieżącym projektem' : _label;
    _localNotifications.show(
      _reminderNotificationId,
      'Nadal pracujesz?',
      'Timer działa już ${_formatElapsed(elapsed)} nad $label. '
          'Otwórz TimeDock, aby zatrzymać lub przyciąć sesję.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _reminderChannelId,
          'Przypomnienia',
          channelDescription: 'Ostrzeżenie o długo działającym timerze',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') FlutterForegroundTask.sendDataToMain('stop');
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _localNotifications.cancel(_reminderNotificationId);
  }
}

String _formatElapsed(int millis) {
  final d = Duration(milliseconds: millis);
  final h = d.inHours;
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}
