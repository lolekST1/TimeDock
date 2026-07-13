import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/domain/services/forgotten_timer.dart';

import '../helpers.dart';

void main() {
  final start = DateTime.utc(2026, 7, 10, 8);
  const settings = ForgottenTimerSettings();

  test('does not remind before the threshold', () {
    final s = session(start: start, end: null);
    expect(
      ForgottenTimer.shouldRemind(
          s, start.add(const Duration(hours: 3)), settings),
      isFalse,
    );
  });

  test('reminds at or past the threshold', () {
    final s = session(start: start, end: null);
    expect(
      ForgottenTimer.shouldRemind(
          s, start.add(const Duration(hours: 4)), settings),
      isTrue,
    );
  });

  test('never reminds for a finished session', () {
    final s = session(start: start, end: start.add(const Duration(hours: 9)));
    expect(
      ForgottenTimer.shouldRemind(
          s, start.add(const Duration(hours: 10)), settings),
      isFalse,
    );
  });

  test('respects the disabled setting', () {
    final s = session(start: start, end: null);
    expect(
      ForgottenTimer.shouldRemind(
        s,
        start.add(const Duration(hours: 8)),
        const ForgottenTimerSettings(enabled: false),
      ),
      isFalse,
    );
  });

  test('suggested trim end is the moment the reminder would have fired', () {
    final s = session(start: start, end: null);
    final now = start.add(const Duration(hours: 14)); // left overnight
    expect(
      ForgottenTimer.suggestedTrimEndUtc(s, now, settings),
      start.add(const Duration(hours: 4)),
    );
  });

  test('suggested trim end never exceeds now', () {
    final s = session(start: start, end: null);
    final now = start.add(const Duration(hours: 2));
    expect(ForgottenTimer.suggestedTrimEndUtc(s, now, settings), now);
  });
}
