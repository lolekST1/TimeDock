import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/data/db/database.dart';
import 'package:timedock/data/repositories/drift_project_repository.dart';
import 'package:timedock/data/repositories/drift_session_repository.dart';
import 'package:timedock/data/repositories/drift_workspace_repository.dart';
import 'package:timedock/data/session_editor.dart';
import 'package:timedock/domain/entities/project.dart';
import 'package:timedock/domain/entities/workspace.dart';
import 'package:timedock/domain/repositories/session_repository.dart';

import '../helpers.dart';

void main() {
  late TimeDockDatabase db;
  late DriftSessionRepository sessions;
  late SessionEditor editor;

  final day = DateTime.utc(2026, 7, 10);
  DateTime at(int h, [int m = 0]) => day.add(Duration(hours: h, minutes: m));

  setUp(() async {
    db = TimeDockDatabase(DatabaseConnection(NativeDatabase.memory()));
    sessions = DriftSessionRepository(db);
    editor = SessionEditor(sessions);
    await DriftWorkspaceRepository(db).upsert(Workspace(
        id: 'w1', name: 'w1', colorSeed: 0, createdAt: day, updatedAt: day));
    await DriftProjectRepository(db).upsert(Project(
        id: 'p1', workspaceId: 'w1', name: 'p1', color: 0, createdAt: day, updatedAt: day));
  });

  tearDown(() => db.close());

  test('saves a non-conflicting manual session', () async {
    final s = session(id: 'm', start: at(8), end: at(9), isManuallyAdded: true);
    final result = await editor.save(s);
    expect(result, isA<EditSaved>());
    expect(await sessions.getActive(), isNull);
  });

  test('rejects a session with end before start', () async {
    final s = session(id: 'm', start: at(9), end: at(8));
    expect(await editor.save(s), isA<EditInvalid>());
  });

  test('auto-trims a trimmable neighbour', () async {
    await editor.save(session(id: 'a', start: at(8), end: at(9)));
    // New session starts inside 'a'.
    final result =
        await editor.save(session(id: 'b', start: at(8, 30), end: at(10)));
    expect(result, isA<EditSaved>());

    final all = await sessions.listOverlappingRange('w1', at(0), at(23));
    final a = all.firstWhere((s) => s.id == 'a');
    expect(a.endUtc, at(8, 30)); // trimmed
    expect(a.wasEdited, isTrue);
  });

  test('surfaces an unresolvable conflict instead of saving', () async {
    await editor.save(session(id: 'outer', start: at(8), end: at(12)));
    final result =
        await editor.save(session(id: 'inner', start: at(9), end: at(10)));
    expect(result, isA<EditConflict>());
    // Inner was not saved.
    final all = await sessions.listOverlappingRange('w1', at(0), at(23));
    expect(all.any((s) => s.id == 'inner'), isFalse);
  });

  test('split persists both halves', () async {
    await editor.save(session(id: 'orig', start: at(8), end: at(11)));
    await editor.split(
      (await sessions.listOverlappingRange('w1', at(0), at(23)))
          .firstWhere((s) => s.id == 'orig'),
      atUtc: at(9),
      atOffsetMinutes: 0,
      nowUtc: at(20),
    );
    final all = await sessions.listOverlappingRange('w1', at(0), at(23));
    expect(all, hasLength(2));
    expect(all.map((s) => s.duration).toSet(),
        {const Duration(hours: 1), const Duration(hours: 2)});
  });

  test('buildManual flags the session and preserves context', () {
    final s = editor.buildManual(
      context: const SessionContext(workspaceId: 'w1', projectId: 'p1'),
      startUtc: at(8),
      endUtc: at(9),
      startOffsetMinutes: 0,
      endOffsetMinutes: 0,
      nowUtc: at(20),
    );
    expect(s.isManuallyAdded, isTrue);
    expect(s.projectId, 'p1');
    expect(s.duration, const Duration(hours: 1));
  });
}
