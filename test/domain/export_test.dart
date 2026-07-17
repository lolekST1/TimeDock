import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/domain/services/csv_exporter.dart';
import 'package:timedock/domain/services/export_config.dart';

void main() {
  group('ExportRounding', () {
    test('rounds up to the increment', () {
      const r = ExportRounding(increment: Duration(minutes: 15));
      expect(r.apply(const Duration(minutes: 1)), const Duration(minutes: 15));
      expect(r.apply(const Duration(minutes: 15)), const Duration(minutes: 15));
      expect(r.apply(const Duration(minutes: 16)), const Duration(minutes: 30));
    });

    test('rounds to nearest when roundUp is false', () {
      const r = ExportRounding(increment: Duration(minutes: 15), roundUp: false);
      expect(r.apply(const Duration(minutes: 7)), Duration.zero);
      expect(r.apply(const Duration(minutes: 8)), const Duration(minutes: 15));
    });

    test('none leaves the duration unchanged', () {
      expect(ExportRounding.none.apply(const Duration(minutes: 7)),
          const Duration(minutes: 7));
    });
  });

  group('ExportConfig.formatDuration', () {
    test('hours:minutes format', () {
      const c = ExportConfig();
      expect(c.formatDuration(const Duration(hours: 1, minutes: 15)), '1:15');
      expect(c.formatDuration(const Duration(minutes: 5)), '0:05');
    });

    test('decimal hours format', () {
      const c = ExportConfig(hourFormat: HourFormat.decimalHours);
      expect(c.formatDuration(const Duration(hours: 1, minutes: 15)), '1.25');
    });

    test('decimal comma when separator is not a comma', () {
      const c = ExportConfig(
        csvSeparator: ';',
        hourFormat: HourFormat.decimalHours,
        decimalComma: true,
      );
      expect(c.formatDuration(const Duration(hours: 1, minutes: 30)), '1,50');
    });

    test('decimal comma is suppressed when separator is a comma', () {
      const c = ExportConfig(
        hourFormat: HourFormat.decimalHours,
        decimalComma: true,
      );
      expect(c.formatDuration(const Duration(hours: 1, minutes: 30)), '1.50');
    });

    test('rounding applies before formatting', () {
      const c = ExportConfig(
        rounding: ExportRounding(increment: Duration(minutes: 15)),
      );
      expect(c.formatDuration(const Duration(minutes: 16)), '0:30');
    });
  });

  group('CsvExporter.perSession', () {
    final rows = [
      const ExportRow(
        date: '2026-07-10',
        start: '08:00',
        end: '09:10',
        duration: Duration(hours: 1, minutes: 10),
        workspace: 'Praca',
        project: 'Projekt1',
        task: 'PROJ-1234',
        jiraId: 'PROJ-1234',
      ),
    ];

    test('writes a header and one row per session', () {
      final csv = CsvExporter.perSession(rows, const ExportConfig());
      final lines = csv.trim().split('\n');
      expect(lines, hasLength(2));
      expect(lines.first, startsWith('Data,Start,Koniec,Czas'));
      expect(lines[1], contains('Projekt1'));
      expect(lines[1], contains('1:10'));
    });

    test('escapes fields containing the separator or quotes', () {
      final tricky = [
        const ExportRow(
          date: '2026-07-10',
          start: '08:00',
          end: '09:00',
          duration: Duration(hours: 1),
          workspace: 'Praca',
          project: 'Projekt1',
          comment: 'spotkanie, ważne "pilne"',
        ),
      ];
      final csv = CsvExporter.perSession(tricky, const ExportConfig());
      // The comma inside the comment must be quoted and inner quotes doubled.
      expect(csv, contains('"spotkanie, ważne ""pilne"""'));
    });

    test('respects a custom separator', () {
      final csv = CsvExporter.perSession(
          rows, const ExportConfig(csvSeparator: ';'));
      expect(csv.split('\n').first, contains('Data;Start;Koniec'));
    });
  });

  group('CsvExporter.aggregated', () {
    test('summary lines with totals and counts', () {
      final csv = CsvExporter.aggregated([
        const AggregateRow(
          project: 'Projekt2',
          subProject: 'Podprojekt1',
          task: 'TASK-123',
          total: Duration(hours: 8),
          sessionCount: 3,
        ),
      ], const ExportConfig());
      final lines = csv.trim().split('\n');
      expect(lines.first, startsWith('Projekt,Podprojekt,Zadanie'));
      expect(lines[1], contains('Projekt2'));
      expect(lines[1], contains('8:00'));
      expect(lines[1], endsWith('3'));
    });
  });
}
