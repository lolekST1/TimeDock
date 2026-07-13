import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/data/db/database.dart';
import 'package:timedock/data/repositories/drift_project_repository.dart';
import 'package:timedock/data/repositories/drift_session_repository.dart';
import 'package:timedock/data/repositories/drift_workspace_repository.dart';
import 'package:timedock/domain/entities/project.dart';
import 'package:timedock/domain/entities/workspace.dart';
import 'package:timedock/domain/repositories/session_repository.dart';
import 'package:timedock/domain/services/timer_service.dart';

void main() {
  late TimeDockDatabase db;
  late DriftSessionRepository sessions;
  late TimerService timer;

  var clock = DateTime.utc(2026, 7, 10, 8);
  final now = DateTime.utc(2026, 7, 10, 8);

  setUp(() async {
    clock = now;
    db = TimeDockDatabase(DatabaseConnection(NativeDatabase.memory()));
    sessions = DriftSessionRepository(db);
    final workspaces = DriftWorkspaceRepository(db);
    final projects = DriftProjectRepository(db);
    await workspaces.upsert(Workspace(
        id: 'w1',
        name: 'w1',
        colorSeed: 0,
        createdAt: now,
        updatedAt: now));
    for (final id in ['p1', 'p2']) {
      await projects.upsert(Project(
          id: id,
          workspaceId: 'w1',
          name: id,
          color: 0,
          createdAt: now,
          updatedAt: now));
    }
    timer = TimerService(sessions, nowUtc: () => clock);
  });

  tearDown(() => db.close());

  SessionContext ctx(String projectId) =>
      SessionContext(workspaceId: 'w1', projectId: projectId);

  test('start creates a running session', () async {
    final s = await timer.start(ctx('p1'));
    expect(s.isRunning, isTrue);
    expect(s.projectId, 'p1');
    expect(await sessions.getActive(), isNotNull);
  });

  test('starting a new timer stops and saves the previous one', () async {
    await timer.start(ctx('p1'));
    clock = now.add(const Duration(hours: 1));
    final second = await timer.start(ctx('p2'));

    final active = await sessions.getActive();
    expect(active!.id, second.id);
    expect(active.projectId, 'p2');

    // Exactly one running session ever.
    final all = await sessions.listOverlappingRange(
        'w1', now.subtract(const Duration(days: 1)), clock.add(const Duration(days: 1)));
    expect(all.where((s) => s.isRunning), hasLength(1));

    final firstStopped = all.firstWhere((s) => s.projectId == 'p1');
    expect(firstStopped.isRunning, isFalse);
    expect(firstStopped.endUtc, now.add(const Duration(hours: 1)));
  });

  test('stop closes the running session', () async {
    await timer.start(ctx('p1'));
    clock = now.add(const Duration(minutes: 30));
    final stopped = await timer.stop();
    expect(stopped!.isRunning, isFalse);
    expect(stopped.duration, const Duration(minutes: 30));
    expect(await sessions.getActive(), isNull);
  });

  test('stop with nothing running is a no-op', () async {
    expect(await timer.stop(), isNull);
  });

  test('switchContext keeps the same session and start time', () async {
    final started = await timer.start(ctx('p1'));
    clock = now.add(const Duration(minutes: 10));
    final switched = await timer.switchContext(ctx('p2'));
    expect(switched!.id, started.id);
    expect(switched.projectId, 'p2');
    expect(switched.startUtc, started.startUtc);
    expect(switched.isRunning, isTrue);
  });

  test('backwards clock never produces a negative duration', () async {
    await timer.start(ctx('p1'));
    clock = now.subtract(const Duration(minutes: 5)); // clock jumped back
    final stopped = await timer.stop();
    expect(stopped!.duration, Duration.zero);
    expect(stopped.endUtc, stopped.startUtc);
  });

  test('active timer is recovered from the database (survives restart)',
      () async {
    await timer.start(ctx('p1'));
    // Simulate a fresh process: a brand-new service over the same database.
    final revived = TimerService(sessions, nowUtc: () => clock);
    clock = now.add(const Duration(hours: 2));
    final stopped = await revived.stop();
    expect(stopped, isNotNull);
    expect(stopped!.projectId, 'p1');
    expect(stopped.duration, const Duration(hours: 2));
  });
}
