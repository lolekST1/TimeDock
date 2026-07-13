import '../entities/time_session.dart';

/// Per-workspace settings for the forgotten-timer safety net (§5.3).
class ForgottenTimerSettings {
  const ForgottenTimerSettings({
    this.enabled = true,
    this.threshold = const Duration(hours: 4),
  });

  final bool enabled;

  /// A running timer older than this is considered possibly forgotten.
  final Duration threshold;
}

/// Pure logic behind the forgotten-timer reminder and the trim suggestion.
///
/// A timer left running overnight would otherwise produce a 14-hour session
/// that quietly corrupts reports; this is the more common failure than the
/// "untracked time" gap, so it gets an explicit guard.
abstract final class ForgottenTimer {
  /// Whether [session] running until [nowUtc] has crossed the reminder
  /// threshold and should prompt "still working on X?".
  static bool shouldRemind(
    TimeSession session,
    DateTime nowUtc,
    ForgottenTimerSettings settings,
  ) {
    if (!settings.enabled) return false;
    if (!session.isRunning) return false;
    return session.durationAt(nowUtc) >= settings.threshold;
  }

  /// Whether the STOP screen should offer to trim the end of [session]
  /// instead of saving a very long span.
  static bool shouldSuggestTrimOnStop(
    TimeSession session,
    DateTime nowUtc,
    ForgottenTimerSettings settings,
  ) =>
      shouldRemind(session, nowUtc, settings);

  /// A sensible default trimmed end for a forgotten session: [nowUtc] minus
  /// the overshoot beyond the threshold, i.e. the moment the reminder would
  /// have first fired. The user can still pick any other end.
  static DateTime suggestedTrimEndUtc(
    TimeSession session,
    DateTime nowUtc,
    ForgottenTimerSettings settings,
  ) {
    final proposed = session.startUtc.add(settings.threshold);
    if (proposed.isBefore(session.startUtc)) return session.startUtc;
    if (proposed.isAfter(nowUtc)) return nowUtc;
    return proposed;
  }
}
