import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/entities/time_session.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/services/timer_foreground_service.dart';

/// Android implementation of [TimerForegroundService] talking to the app's
/// own native side over a method channel.
///
/// The notification's elapsed time is rendered by the SYSTEM chronometer
/// (setUsesChronometer), so it keeps ticking with the screen off. On `start`
/// the native side also runs a foreground service for the timer's lifetime;
/// its job is to keep the app process out of the frozen/cached state so the
/// scheduled forgotten-timer reminder actually fires in the background instead
/// of being deferred by OEMs (ColorOS/Oppo) until the app is reopened. STOP on
/// the notification is handled natively: the exact stop instant is persisted
/// (pending stop) and the Dart side is poked if alive; on next launch/resume
/// [takePendingStop] closes the session at that recorded moment.
class AndroidTimerForegroundService implements TimerForegroundService {
  AndroidTimerForegroundService({
    required this.onStopRequested,
    required this.onStartRequested,
  }) {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'stopRequested':
          onStopRequested();
        case 'startRequested':
          onStartRequested();
      }
    });
  }

  static const _channel = MethodChannel('timedock/timer_service');

  /// Invoked when STOP is pressed while the Dart side is alive.
  final void Function() onStopRequested;

  /// Invoked when a start is triggered from the widget/tile while the Dart side
  /// is alive, so the pending start is applied to the database immediately.
  final void Function() onStartRequested;

  @override
  Future<void> show(TimeSession session, String contextLabel) async {
    try {
      await _channel.invokeMethod<void>('start', {
        'startMillis': session.startUtc.millisecondsSinceEpoch,
        'title': contextLabel.isEmpty ? 'TimeDock — pomiar' : contextLabel,
      });
    } on PlatformException catch (e) {
      // The notification is a convenience surface; never break the timer.
      debugPrint('Timer notification failed: ${e.code} ${e.message}');
    }
  }

  @override
  Future<void> hide() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException catch (e) {
      debugPrint('Timer notification cancel failed: ${e.code} ${e.message}');
    }
  }

  @override
  Future<DateTime?> takePendingStop() async {
    final millis = await _channel.invokeMethod<int>('takePendingStop');
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  @override
  Future<PendingStart?> takePendingStart() async {
    final raw = await _channel.invokeMethod<String>('takePendingStart');
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final startMillis = (map['startMillis'] as num).toInt();
      return PendingStart(
        context: SessionContext(
          workspaceId: map['workspaceId'] as String,
          projectId: map['projectId'] as String,
          subProjectId: map['subProjectId'] as String?,
          taskId: map['taskId'] as String?,
        ),
        startUtc: DateTime.fromMillisecondsSinceEpoch(startMillis, isUtc: true),
      );
    } on FormatException catch (e) {
      debugPrint('Bad pending start payload: $e');
      return null;
    }
  }

  @override
  Future<void> updateWidget(String recentContextsJson) async {
    try {
      await _channel.invokeMethod<void>(
          'updateWidget', {'contexts': recentContextsJson});
    } on PlatformException catch (e) {
      debugPrint('Widget update failed: ${e.code} ${e.message}');
    }
  }
}
