import 'package:uuid/uuid.dart';

import '../entities/time_session.dart';
import '../repositories/session_repository.dart';

/// Enforces the core rule of TimeDock: at most one running timer.
///
/// Starting a timer is a single, atomic intent — it closes whatever was
/// running (persisting that session) and opens a new one. The database record
/// with `endUtc == null` is the source of truth, so the timer survives process
/// death: nothing here holds state in memory.
class TimerService {
  TimerService(
    this._sessions, {
    Uuid uuid = const Uuid(),
    DateTime Function()? nowUtc,
  })  : _uuid = uuid,
        _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final SessionRepository _sessions;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

  /// Local UTC offset captured at the moment of the event, so wall-clock
  /// rendering matches what the user experienced (see [TimeSession]).
  int _offsetMinutes(DateTime utcNow) =>
      utcNow.toLocal().timeZoneOffset.inMinutes;

  /// Starts a timer for [context], stopping and saving any running session
  /// first. Returns the newly started session. This is the one-tap path.
  Future<TimeSession> start(SessionContext context) async {
    final now = _nowUtc();
    await _stopActiveAt(now);

    final session = TimeSession(
      id: _uuid.v4(),
      workspaceId: context.workspaceId,
      projectId: context.projectId,
      subProjectId: context.subProjectId,
      taskId: context.taskId,
      startUtc: now,
      startOffsetMinutes: _offsetMinutes(now),
      createdAt: now,
      updatedAt: now,
    );
    await _sessions.upsert(session);
    return session;
  }

  /// Stops the running timer, if any. Returns the saved session or null.
  Future<TimeSession?> stop() => _stopActiveAt(_nowUtc());

  /// Changes the context of the running timer without restarting the clock.
  /// No-op when nothing is running.
  Future<TimeSession?> switchContext(SessionContext context) async {
    final active = await _sessions.getActive();
    if (active == null) return null;
    final now = _nowUtc();
    final updated = active.copyWith(
      projectId: context.projectId,
      subProjectId: context.subProjectId,
      taskId: context.taskId,
      updatedAt: now,
    );
    await _sessions.upsert(updated);
    return updated;
  }

  Future<TimeSession?> _stopActiveAt(DateTime now) async {
    final active = await _sessions.getActive();
    if (active == null) return null;
    // Guard against a clock that appears to run backwards (e.g. NTP
    // correction): never persist an end before the start.
    final end = now.isAfter(active.startUtc) ? now : active.startUtc;
    final stopped = active.copyWith(
      endUtc: end,
      endOffsetMinutes: _offsetMinutes(end),
      updatedAt: end,
    );
    await _sessions.upsert(stopped);
    return stopped;
  }
}
