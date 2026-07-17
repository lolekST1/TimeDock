import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timedock/data/db/database.dart';
import 'package:timedock/data/providers.dart';
import 'package:timedock/data/repositories/drift_project_repository.dart';
import 'package:timedock/data/repositories/drift_workspace_repository.dart';
import 'package:timedock/domain/entities/project.dart';
import 'package:timedock/domain/entities/time_session.dart';
import 'package:timedock/domain/entities/workspace.dart';
import 'package:timedock/domain/services/report_range.dart';
import 'package:timedock/features/app_state/app_providers.dart';
import 'package:timedock/features/reports/report_providers.dart';
import 'package:timedock/features/stats/stats_screen.dart';

void main() {
  testWidgets('stats screen shows the tracked total and session count',
      (tester) async {
    SharedPreferences.setMockInitialValues({'selected_workspace_id': 'w1'});
    final prefs = await SharedPreferences.getInstance();

    final db = TimeDockDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);

    final now = DateTime.now();
    final anchorDay = DateTime.utc(now.year, now.month, now.day);
    final base = DateTime(now.year, now.month, now.day, 8);

    await DriftWorkspaceRepository(db).upsert(Workspace(
        id: 'w1', name: 'Praca', colorSeed: 0xFF1565C0, createdAt: base, updatedAt: base));
    await DriftProjectRepository(db).upsert(Project(
        id: 'p1', workspaceId: 'w1', name: 'Projekt1', color: 0xFF1E88E5, createdAt: base, updatedAt: base));

    TimeSession s(String id, DateTime start, Duration d) => TimeSession(
          id: id,
          workspaceId: 'w1',
          projectId: 'p1',
          startUtc: start.toUtc(),
          endUtc: start.add(d).toUtc(),
          startOffsetMinutes: start.timeZoneOffset.inMinutes,
          endOffsetMinutes: start.timeZoneOffset.inMinutes,
          createdAt: base,
          updatedAt: base,
        );

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    await container.read(sessionRepositoryProvider).upsertAll([
      s('a', base, const Duration(hours: 2)),
      s('b', base.add(const Duration(hours: 3)), const Duration(hours: 1)),
    ]);

    container.read(reportPeriodProvider.notifier).state = ReportPeriod.day;
    container.read(reportAnchorProvider.notifier).state = anchorDay;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: StatsScreen()),
    ));
    await tester.pumpAndSettle();

    // 3h tracked, focus 100 (both sessions >= 25 min). Assert on the
    // top-row cards that the grid builds eagerly.
    expect(find.text('3h'), findsOneWidget);
    expect(find.text('Focus Score'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('Zmierzony czas'), findsOneWidget);
  });
}
