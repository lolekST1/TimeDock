import 'package:drift/drift.dart';

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Workspaces, Projects, SubProjects, Tasks, TimeSessions],
)
class TimeDockDatabase extends _$TimeDockDatabase {
  TimeDockDatabase(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createIndexes();
        },
        onUpgrade: (m, from, to) async {
          // v2: per-workspace weekly goal.
          if (from < 2) {
            await m.addColumn(workspaces, workspaces.weeklyGoalMinutes);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  Future<void> _createIndexes() async {
    // The timer lookup (endUtcMillis IS NULL) and the day/report range scans
    // are the two hot paths.
    await customStatement(
        'CREATE INDEX idx_sessions_active ON time_sessions (end_utc_millis) '
        'WHERE end_utc_millis IS NULL');
    await customStatement(
        'CREATE INDEX idx_sessions_workspace_start ON time_sessions '
        '(workspace_id, start_utc_millis)');
    await customStatement(
        'CREATE INDEX idx_projects_workspace ON projects (workspace_id)');
  }
}
