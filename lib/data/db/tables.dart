import 'package:drift/drift.dart';

/// All timestamps are stored as integer milliseconds since epoch, UTC —
/// unambiguous across devices and immune to DateTime serialization quirks.
/// Wall-clock rendering uses the stored UTC offsets on sessions.
mixin AuditColumns on Table {
  IntColumn get createdAtMillis => integer()();
  IntColumn get updatedAtMillis => integer()();
}

@DataClassName('WorkspaceRow')
class Workspaces extends Table with AuditColumns {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorSeed => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// Optional weekly target in minutes (added in schema v2).
  IntColumn get weeklyGoalMinutes => integer().nullable()();

  /// Marks the workspace for the worklog (timesheet) export (added in v3).
  BoolColumn get exportsToTimesheet =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ProjectRow')
class Projects extends Table with AuditColumns {
  TextColumn get id => text()();
  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SubProjectRow')
class SubProjects extends Table with AuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get name => text()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TaskRow')
class Tasks extends Table with AuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get subProjectId =>
      text().nullable().references(SubProjects, #id)();
  TextColumn get name => text()();
  TextColumn get jiraId => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TimeSessionRow')
class TimeSessions extends Table with AuditColumns {
  TextColumn get id => text()();
  TextColumn get workspaceId => text().references(Workspaces, #id)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get subProjectId =>
      text().nullable().references(SubProjects, #id)();
  TextColumn get taskId => text().nullable().references(Tasks, #id)();

  IntColumn get startUtcMillis => integer()();

  /// Null while the session is the running timer.
  IntColumn get endUtcMillis => integer().nullable()();
  IntColumn get startOffsetMinutes => integer()();
  IntColumn get endOffsetMinutes => integer().nullable()();
  TextColumn get comment => text().nullable()();
  BoolColumn get isManuallyAdded =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get wasEdited => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
