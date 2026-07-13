import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/features/stats/stats_providers.dart';

void main() {
  group('WeeklyGoalProgress', () {
    test('fraction is tracked/goal, clamped to 1', () {
      const half = WeeklyGoalProgress(
          goal: Duration(hours: 10), tracked: Duration(hours: 5));
      expect(half.fraction, 0.5);
      expect(half.reached, isFalse);
      expect(half.remaining, const Duration(hours: 5));

      const over = WeeklyGoalProgress(
          goal: Duration(hours: 10), tracked: Duration(hours: 12));
      expect(over.fraction, 1.0);
      expect(over.reached, isTrue);
      expect(over.remaining, Duration.zero);
    });

    test('zero goal never divides by zero', () {
      const g = WeeklyGoalProgress(
          goal: Duration.zero, tracked: Duration(hours: 1));
      expect(g.fraction, 0);
    });
  });
}
