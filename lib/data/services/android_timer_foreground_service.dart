import 'package:flutter/services.dart';

import '../../domain/entities/time_session.dart';
import '../../domain/services/timer_foreground_service.dart';

/// Android implementation of [TimerForegroundService] talking to the app's
/// own native TimerService over a method channel.
///
/// The notification's elapsed time is rendered by the SYSTEM chronometer
/// (setUsesChronometer), so it keeps ticking with the screen off regardless of
/// Doze or OEM throttling — no isolate needs to stay alive. STOP on the
/// notification is handled natively: the exact stop instant is persisted
/// (pending stop) and the Dart side is poked if alive; on next launch/resume
/// [takePendingStop] closes the session at that recorded moment.
class AndroidTimerForegroundService implements TimerForegroundService {
  AndroidTimerForegroundService({required this.onStopRequested}) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stopRequested') onStopRequested();
    });
  }

  static const _channel = MethodChannel('timedock/timer_service');

  /// Invoked when STOP is pressed while the Dart side is alive.
  final void Function() onStopRequested;

  @override
  Future<void> show(TimeSession session, String contextLabel) {
    return _channel.invokeMethod<void>('start', {
      'startMillis': session.startUtc.millisecondsSinceEpoch,
      'title': contextLabel.isEmpty ? 'TimeDock — pomiar' : contextLabel,
    });
  }

  @override
  Future<void> hide() => _channel.invokeMethod<void>('stop');

  @override
  Future<DateTime?> takePendingStop() async {
    final millis = await _channel.invokeMethod<int>('takePendingStop');
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }
}
