import '../entities/time_session.dart';
import '../repositories/session_repository.dart';

/// A start requested from the home-screen widget while the app was dead: the
/// chosen [context] and the instant the user tapped. When [switchOnly] is true
/// a timer was already running and the intent is to switch its context in place
/// (keep the clock), not start a new session.
class PendingStart {
  const PendingStart({
    required this.context,
    required this.startUtc,
    this.switchOnly = false,
  });

  final SessionContext context;
  final DateTime startUtc;
  final bool switchOnly;
}

/// Platform seam for the always-on timer notification / foreground service.
///
/// Kept in the domain as a pure interface so the rest of the app depends only
/// on this contract. The Android implementation (a started foreground service
/// showing a chronometer notification with STOP / "switch to…" actions) and a
/// future iOS Live Activity live behind it; the timer's correctness never
/// depends on the service being alive, because the running database record is
/// the source of truth.
abstract interface class TimerForegroundService {
  /// Show/refresh the ongoing notification for the running [session] with the
  /// given human-readable [contextLabel].
  Future<void> show(TimeSession session, String contextLabel);

  /// Remove the ongoing notification and stop the foreground service.
  Future<void> hide();

  /// If the user pressed STOP on the notification while the app was frozen or
  /// dead, returns the recorded stop instant (UTC) exactly once, so the
  /// session can be closed at the moment STOP was actually pressed.
  Future<DateTime?> takePendingStop();

  /// If a timer was started from the widget/tile while the app was frozen or
  /// dead, returns the recorded context + start instant exactly once, so the
  /// session can be created at the moment the user tapped.
  Future<PendingStart?> takePendingStart();

  /// Push the recent-context list (JSON, consumed by the native widget) to
  /// shared storage and re-render the home-screen widget.
  Future<void> updateWidget(String recentContextsJson);
}

/// Default no-op used in tests, on unsupported platforms, and until the native
/// implementation is wired in. Making it a no-op keeps the timer fully
/// functional without the service.
class NoopTimerForegroundService implements TimerForegroundService {
  const NoopTimerForegroundService();

  @override
  Future<void> show(TimeSession session, String contextLabel) async {}

  @override
  Future<void> hide() async {}

  @override
  Future<DateTime?> takePendingStop() async => null;

  @override
  Future<PendingStart?> takePendingStart() async => null;

  @override
  Future<void> updateWidget(String recentContextsJson) async {}
}
