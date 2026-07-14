import 'package:flutter_foreground_task/flutter_foreground_task.dart';

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
/// notification and forwards the STOP button to the main isolate.
class TimerTaskHandler extends TaskHandler {
  int _startMillis = DateTime.now().millisecondsSinceEpoch;
  String _label = '';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _startMillis =
        await FlutterForegroundTask.getData<int>(key: 'startMillis') ??
            _startMillis;
    _label = await FlutterForegroundTask.getData<String>(key: 'label') ?? '';
    _render();
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map) {
      final start = data['startMillis'];
      if (start is num) _startMillis = start.toInt();
      final label = data['label'];
      if (label is String) _label = label;
      _render();
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) => _render();

  void _render() {
    final elapsed = DateTime.now().millisecondsSinceEpoch - _startMillis;
    FlutterForegroundTask.updateService(
      notificationTitle: _label.isEmpty ? 'TimeDock — pomiar' : _label,
      notificationText: _formatElapsed(elapsed < 0 ? 0 : elapsed),
    );
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') FlutterForegroundTask.sendDataToMain('stop');
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

String _formatElapsed(int millis) {
  final d = Duration(milliseconds: millis);
  final h = d.inHours;
  final m = (d.inMinutes % 60).toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$h:$m:$s';
}
