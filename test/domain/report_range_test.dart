import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/domain/services/report_range.dart';

void main() {
  // 2026-07-10 is a Friday.
  final friday = DateTime.utc(2026, 7, 10);

  group('rangeFor', () {
    test('day range is a single day', () {
      final r = ReportRangeCalculator.rangeFor(ReportPeriod.day, friday);
      expect(r.firstDay, friday);
      expect(r.lastDay, friday);
    });

    test('week range is Monday..Sunday around the anchor', () {
      final r = ReportRangeCalculator.rangeFor(ReportPeriod.week, friday);
      expect(r.firstDay, DateTime.utc(2026, 7, 6)); // Monday
      expect(r.lastDay, DateTime.utc(2026, 7, 12)); // Sunday
    });

    test('month range spans the whole month', () {
      final r = ReportRangeCalculator.rangeFor(ReportPeriod.month, friday);
      expect(r.firstDay, DateTime.utc(2026, 7, 1));
      expect(r.lastDay, DateTime.utc(2026, 7, 31));
    });

    test('February month range handles length correctly', () {
      final r = ReportRangeCalculator.rangeFor(
          ReportPeriod.month, DateTime.utc(2026, 2, 15));
      expect(r.lastDay, DateTime.utc(2026, 2, 28));
    });

    test('contains checks inclusive bounds', () {
      final r = ReportRangeCalculator.rangeFor(ReportPeriod.week, friday);
      expect(r.contains(DateTime.utc(2026, 7, 6)), isTrue);
      expect(r.contains(DateTime.utc(2026, 7, 12)), isTrue);
      expect(r.contains(DateTime.utc(2026, 7, 13)), isFalse);
    });
  });

  group('shift', () {
    test('day shifts by one day', () {
      expect(ReportRangeCalculator.shift(ReportPeriod.day, friday, -1),
          DateTime.utc(2026, 7, 9));
    });

    test('week shifts by seven days', () {
      expect(ReportRangeCalculator.shift(ReportPeriod.week, friday, 1),
          DateTime.utc(2026, 7, 17));
    });

    test('month shifts by one month', () {
      expect(ReportRangeCalculator.shift(ReportPeriod.month, friday, -1),
          DateTime.utc(2026, 6, 10));
      // Crossing a year boundary.
      expect(
          ReportRangeCalculator.shift(
              ReportPeriod.month, DateTime.utc(2026, 12, 5), 1),
          DateTime.utc(2027, 1, 5));
    });
  });

  group('custom range', () {
    test('rangeFor throws for the custom period', () {
      expect(() => ReportRangeCalculator.rangeFor(ReportPeriod.custom, friday),
          throwsArgumentError);
    });

    test('shiftCustom pages by the range length', () {
      final range = ReportRange(
        firstDay: DateTime.utc(2026, 7, 6),
        lastDay: DateTime.utc(2026, 7, 8), // 3 days
      );
      final next = ReportRangeCalculator.shiftCustom(range, 1);
      expect(next.firstDay, DateTime.utc(2026, 7, 9));
      expect(next.lastDay, DateTime.utc(2026, 7, 11));

      final prev = ReportRangeCalculator.shiftCustom(range, -1);
      expect(prev.firstDay, DateTime.utc(2026, 7, 3));
      expect(prev.lastDay, DateTime.utc(2026, 7, 5));
    });
  });
}
