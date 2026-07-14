import '../entities/time_session.dart';

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
}
