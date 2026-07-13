import 'dart:convert';

import 'db/database.dart';

/// Versioned JSON backup of the whole database. The JSON format is the
/// migration vehicle to iOS and the foundation for future sync, so it is
/// explicitly versioned rather than relying on the raw SQLite file.
///
/// The binary SQLite copy is handled separately by the platform layer (copy
/// the database file); this service owns the portable, inspectable format.
class BackupService {
  BackupService(this._db);

  final TimeDockDatabase _db;

  static const formatVersion = 1;

  Future<Map<String, dynamic>> exportToMap() async {
    return {
      'formatVersion': formatVersion,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'workspaces':
          (await _db.select(_db.workspaces).get()).map((r) => r.toJson()).toList(),
      'projects':
          (await _db.select(_db.projects).get()).map((r) => r.toJson()).toList(),
      'subProjects':
          (await _db.select(_db.subProjects).get()).map((r) => r.toJson()).toList(),
      'tasks':
          (await _db.select(_db.tasks).get()).map((r) => r.toJson()).toList(),
      'timeSessions': (await _db.select(_db.timeSessions).get())
          .map((r) => r.toJson())
          .toList(),
    };
  }

  Future<String> exportToJson() async =>
      const JsonEncoder.withIndent('  ').convert(await exportToMap());

  /// Restores from a backup map, upserting every record (idempotent by id).
  /// Inserts in dependency order so foreign keys are satisfied. Existing rows
  /// with the same id are overwritten.
  Future<void> importFromMap(Map<String, dynamic> map) async {
    final version = map['formatVersion'];
    if (version is! int || version > formatVersion) {
      throw const FormatException('Nieobsługiwana wersja kopii zapasowej.');
    }
    List<Map<String, dynamic>> rows(String key) =>
        ((map[key] as List?) ?? const [])
            .cast<Map<String, dynamic>>();

    await _db.transaction(() async {
      for (final j in rows('workspaces')) {
        await _db.into(_db.workspaces).insertOnConflictUpdate(
            WorkspaceRow.fromJson(j).toCompanion(true));
      }
      for (final j in rows('projects')) {
        await _db.into(_db.projects).insertOnConflictUpdate(
            ProjectRow.fromJson(j).toCompanion(true));
      }
      for (final j in rows('subProjects')) {
        await _db.into(_db.subProjects).insertOnConflictUpdate(
            SubProjectRow.fromJson(j).toCompanion(true));
      }
      for (final j in rows('tasks')) {
        await _db.into(_db.tasks).insertOnConflictUpdate(
            TaskRow.fromJson(j).toCompanion(true));
      }
      for (final j in rows('timeSessions')) {
        await _db.into(_db.timeSessions).insertOnConflictUpdate(
            TimeSessionRow.fromJson(j).toCompanion(true));
      }
    });
  }

  Future<void> importFromJson(String json) =>
      importFromMap(jsonDecode(json) as Map<String, dynamic>);
}
