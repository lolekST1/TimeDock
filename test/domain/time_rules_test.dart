import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/domain/services/time_rules.dart';

import '../helpers.dart';

void main() {
  group('localDayKey', () {
    test('uses the offset to find the local day', () {
      // 23:30 UTC at +120 min offset is already 01:30 next day locally.
      final utc = DateTime.utc(2026, 7, 10, 23, 30);
      expect(TimeRules.localDayKey(utc, 120), DateTime.utc(2026, 7, 11));
      expect(TimeRules.localDayKey(utc, 0), DateTime.utc(2026, 7, 10));
      // 00:30 UTC at -120 offset is still the previous local day.
      final utc2 = DateTime.utc(2026, 7, 10, 0, 30);
      expect(TimeRules.localDayKey(utc2, -120), DateTime.utc(2026, 7, 9));
    });
  });

  group('splitByLocalDay', () {
    test('session within one day yields a single slice', () {
      final s = session(
        start: DateTime.utc(2026, 7, 10, 8, 0),
        end: DateTime.utc(2026, 7, 10, 9, 10),
        startOffset: 120,
      );
      final slices = TimeRules.splitByLocalDay(s);
      expect(slices, hasLength(1));
      expect(slices.single.localDay, DateTime.utc(2026, 7, 10));
      expect(slices.single.duration, const Duration(hours: 1, minutes: 10));
    });

    test('session crossing local midnight splits into two exact slices', () {
      // 23:00–01:00 local at +120: 21:00–23:00 UTC.
      final s = session(
        start: DateTime.utc(2026, 7, 10, 21, 0),
        end: DateTime.utc(2026, 7, 10, 23, 0),
        startOffset: 120,
      );
      final slices = TimeRules.splitByLocalDay(s);
      expect(slices, hasLength(2));
      expect(slices[0].localDay, DateTime.utc(2026, 7, 10));
      expect(slices[0].duration, const Duration(hours: 1));
      expect(slices[0].endLocal, DateTime.utc(2026, 7, 11, 0, 0));
      expect(slices[1].localDay, DateTime.utc(2026, 7, 11));
      expect(slices[1].duration, const Duration(hours: 1));
      expect(slices[1].startLocal, DateTime.utc(2026, 7, 11, 0, 0));
    });

    test('multi-day session produces one slice per local day', () {
      final s = session(
        start: DateTime.utc(2026, 7, 10, 22, 0),
        end: DateTime.utc(2026, 7, 13, 5, 0),
      );
      final slices = TimeRules.splitByLocalDay(s);
      expect(slices, hasLength(4));
      final total =
          slices.fold(Duration.zero, (sum, slice) => sum + slice.duration);
      expect(total, s.duration);
      expect(slices.map((x) => x.localDay), [
        DateTime.utc(2026, 7, 10),
        DateTime.utc(2026, 7, 11),
        DateTime.utc(2026, 7, 12),
        DateTime.utc(2026, 7, 13),
      ]);
    });

    test('DST change mid-session preserves total duration', () {
      // Europe/Warsaw autumn change: offset +120 → +60 during the night.
      final s = session(
        start: DateTime.utc(2026, 10, 24, 20, 0),
        end: DateTime.utc(2026, 10, 25, 6, 0),
        startOffset: 120,
        endOffset: 60,
      );
      final slices = TimeRules.splitByLocalDay(s);
      final total =
          slices.fold(Duration.zero, (sum, slice) => sum + slice.duration);
      expect(total, const Duration(hours: 10));
    });

    test('running session slices up to now', () {
      final s = session(start: DateTime.utc(2026, 7, 10, 8, 0), end: null);
      final slices = TimeRules.splitByLocalDay(
        s,
        nowUtc: DateTime.utc(2026, 7, 10, 9, 30),
      );
      expect(slices.single.duration, const Duration(hours: 1, minutes: 30));
    });

    test('running session without nowUtc throws', () {
      final s = session(start: DateTime.utc(2026, 7, 10, 8, 0), end: null);
      expect(() => TimeRules.splitByLocalDay(s), throwsArgumentError);
    });

    test('zero-length session yields no slices', () {
      final start = DateTime.utc(2026, 7, 10, 8, 0);
      final s = session(start: start, end: start);
      expect(TimeRules.splitByLocalDay(s), isEmpty);
    });
  });

  group('durationInDayRange', () {
    test('clips a midnight-crossing session to the requested day', () {
      final s = session(
        start: DateTime.utc(2026, 7, 10, 21, 0),
        end: DateTime.utc(2026, 7, 10, 23, 0),
        startOffset: 120,
      );
      final day10 = DateTime.utc(2026, 7, 10);
      final day11 = DateTime.utc(2026, 7, 11);
      expect(TimeRules.durationInDayRange(s, day10, day10),
          const Duration(hours: 1));
      expect(TimeRules.durationInDayRange(s, day11, day11),
          const Duration(hours: 1));
      expect(TimeRules.durationInDayRange(s, day10, day11),
          const Duration(hours: 2));
    });

    test('returns zero outside the range', () {
      final s = session(
        start: DateTime.utc(2026, 7, 10, 8, 0),
        end: DateTime.utc(2026, 7, 10, 9, 0),
      );
      expect(
        TimeRules.durationInDayRange(
            s, DateTime.utc(2026, 7, 11), DateTime.utc(2026, 7, 12)),
        Duration.zero,
      );
    });
  });
}
