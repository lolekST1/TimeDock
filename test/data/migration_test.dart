import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:timedock/data/db/database.dart';
import 'package:timedock/data/repositories/drift_workspace_repository.dart';

void main() {
  test('migrates a v1 database to v2, adding weeklyGoalMinutes', () async {
    final dir = Directory.systemTemp.createTempSync('timedock_migration');
    final file = File('${dir.path}/db.sqlite');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    // Build a schema-v1 database by hand (no weeklyGoalMinutes column) with an
    // existing workspace row, and stamp user_version = 1.
    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE workspaces (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        color_seed INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at_millis INTEGER NOT NULL,
        updated_at_millis INTEGER NOT NULL
      );
    ''');
    raw.execute(
      'INSERT INTO workspaces '
      '(id, name, color_seed, sort_order, is_archived, created_at_millis, updated_at_millis) '
      "VALUES ('w1', 'Praca', 1, 0, 0, 0, 0);",
    );
    raw.execute('PRAGMA user_version = 1;');
    raw.dispose();

    // Opening through Drift runs onUpgrade(1 -> 2).
    final db = TimeDockDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final workspaces = DriftWorkspaceRepository(db);

    final migrated = await workspaces.getById('w1');
    expect(migrated, isNotNull);
    expect(migrated!.name, 'Praca'); // existing data survived
    expect(migrated.weeklyGoalMinutes, isNull); // new column present, empty

    // The new column is writable after the migration.
    await workspaces.upsert(migrated.copyWith(
        weeklyGoalMinutes: 600, updatedAt: DateTime.now().toUtc()));
    expect((await workspaces.getById('w1'))!.weeklyGoalMinutes, 600);
  });

  test('migrates a v2 database to v3, adding exportsToTimesheet', () async {
    final dir = Directory.systemTemp.createTempSync('timedock_migration_v3');
    final file = File('${dir.path}/db.sqlite');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    // Build a schema-v2 database by hand (weeklyGoalMinutes present, but no
    // exportsToTimesheet column) with an existing workspace, stamped as v2.
    final raw = sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE workspaces (
        id TEXT NOT NULL PRIMARY KEY,
        name TEXT NOT NULL,
        color_seed INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        weekly_goal_minutes INTEGER,
        created_at_millis INTEGER NOT NULL,
        updated_at_millis INTEGER NOT NULL
      );
    ''');
    raw.execute(
      'INSERT INTO workspaces '
      '(id, name, color_seed, sort_order, is_archived, weekly_goal_minutes, '
      'created_at_millis, updated_at_millis) '
      "VALUES ('w1', 'Praca', 1, 0, 0, 600, 0, 0);",
    );
    raw.execute('PRAGMA user_version = 2;');
    raw.dispose();

    // Opening through Drift runs onUpgrade(2 -> 3).
    final db = TimeDockDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final workspaces = DriftWorkspaceRepository(db);

    final migrated = await workspaces.getById('w1');
    expect(migrated, isNotNull);
    expect(migrated!.name, 'Praca'); // existing data survived
    expect(migrated.weeklyGoalMinutes, 600); // v2 data survived
    expect(migrated.exportsToTimesheet, isFalse); // new column defaults to false

    // The new column is writable after the migration.
    await workspaces.upsert(migrated.copyWith(
        exportsToTimesheet: true, updatedAt: DateTime.now().toUtc()));
    expect((await workspaces.getById('w1'))!.exportsToTimesheet, isTrue);
  });
}
