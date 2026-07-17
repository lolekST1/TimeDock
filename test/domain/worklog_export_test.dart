import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/domain/services/worklog_exporter.dart';

void main() {
  WorklogRow row({
    String sessionId = 's1',
    String issueKey = 'PROJ-123',
    String? description,
    String? author,
  }) =>
      WorklogRow(
        sessionId: sessionId,
        issueKey: issueKey,
        startUtc: DateTime.utc(2026, 7, 16, 8),
        endUtc: DateTime.utc(2026, 7, 16, 9, 30),
        durationSeconds: 5400,
        description: description,
        workspace: 'Praca',
        author: author,
      );

  group('WorklogExporter.toJson', () {
    test('serializes one object per session with the agreed shape', () {
      final json = WorklogExporter.toJson([row(description: 'Analiza')]);
      final decoded = jsonDecode(json) as List<Object?>;
      expect(decoded, hasLength(1));
      final obj = decoded.first as Map<String, Object?>;
      expect(obj['sessionId'], 's1');
      expect(obj['issueKey'], 'PROJ-123');
      expect(obj['startUtc'], '2026-07-16T08:00:00.000Z');
      expect(obj['endUtc'], '2026-07-16T09:30:00.000Z');
      expect(obj['durationSeconds'], 5400);
      expect(obj['description'], 'Analiza');
      expect(obj['workspace'], 'Praca');
    });

    test('emits UTC timestamps with a trailing Z even for local input', () {
      final r = WorklogRow(
        sessionId: 's2',
        issueKey: 'PROJ-1',
        startUtc: DateTime.utc(2026, 1, 2, 3, 4, 5),
        endUtc: DateTime.utc(2026, 1, 2, 4, 4, 5),
        durationSeconds: 3600,
        workspace: 'Praca',
      );
      final obj =
          (jsonDecode(WorklogExporter.toJson([r])) as List).first as Map;
      expect(obj['startUtc'], endsWith('Z'));
      expect(obj['endUtc'], endsWith('Z'));
    });

    test('a missing comment serializes as null', () {
      final obj =
          (jsonDecode(WorklogExporter.toJson([row()])) as List).first as Map;
      expect(obj.containsKey('description'), isTrue);
      expect(obj['description'], isNull);
    });

    test('serializes the configured author', () {
      final obj = (jsonDecode(
                  WorklogExporter.toJson([row(author: 'jan@example.com')]))
              as List)
          .first as Map;
      expect(obj['author'], 'jan@example.com');
    });

    test('a missing author serializes as null', () {
      final obj =
          (jsonDecode(WorklogExporter.toJson([row()])) as List).first as Map;
      expect(obj.containsKey('author'), isTrue);
      expect(obj['author'], isNull);
    });

    test('an empty list serializes to an empty JSON array', () {
      expect(jsonDecode(WorklogExporter.toJson(const [])), isEmpty);
    });

    test('preserves the order of the rows given', () {
      final json = WorklogExporter.toJson([
        row(sessionId: 'a', issueKey: 'PROJ-1'),
        row(sessionId: 'b', issueKey: 'PROJ-2'),
      ]);
      final decoded = jsonDecode(json) as List;
      expect((decoded[0] as Map)['sessionId'], 'a');
      expect((decoded[1] as Map)['sessionId'], 'b');
    });
  });
}
