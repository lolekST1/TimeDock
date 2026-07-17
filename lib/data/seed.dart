import 'package:uuid/uuid.dart';

import '../domain/entities/project.dart';
import '../domain/entities/sub_project.dart';
import '../domain/entities/workspace.dart';
import '../domain/repositories/project_repository.dart';
import '../domain/repositories/sub_project_repository.dart';
import '../domain/repositories/workspace_repository.dart';

/// First-run data (§15 of the spec). Everything created here is ordinary,
/// user-editable data — nothing in the app depends on these names existing.
class DatabaseSeeder {
  DatabaseSeeder({
    required this.workspaces,
    required this.projects,
    required this.subProjects,
    Uuid uuid = const Uuid(),
    DateTime Function()? nowUtc,
  })  : _uuid = uuid,
        _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final WorkspaceRepository workspaces;
  final ProjectRepository projects;
  final SubProjectRepository subProjects;
  final Uuid _uuid;
  final DateTime Function() _nowUtc;

  // Neutral placeholder projects — the app ships "clean", with no real client
  // or project names baked in. The user renames these (or deletes them and
  // adds their own) from the UI on first run.
  static const _workProjects = [
    ('Projekt1', 0xFF1E88E5),
    ('Projekt2', 0xFF2E7D32),
    ('Projekt3', 0xFF6D4C41),
  ];

  /// Which seeded project carries example sub-projects, and their names.
  static const _projectWithSubProjects = 'Projekt2';
  static const _subProjectNames = ['Podprojekt1', 'Podprojekt2'];

  /// Seeds initial data if (and only if) the database is empty.
  /// Idempotent: safe to call on every app start.
  Future<void> seedIfEmpty() async {
    if (await workspaces.hasAny()) return;
    final now = _nowUtc();

    final work = Workspace(
      id: _uuid.v4(),
      name: 'Praca',
      colorSeed: 0xFF1565C0,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
    );
    final private = Workspace(
      id: _uuid.v4(),
      name: 'Prywatne',
      colorSeed: 0xFF00695C,
      sortOrder: 1,
      createdAt: now,
      updatedAt: now,
    );
    await workspaces.upsert(work);
    await workspaces.upsert(private);

    for (var i = 0; i < _workProjects.length; i++) {
      final (name, color) = _workProjects[i];
      final project = Project(
        id: _uuid.v4(),
        workspaceId: work.id,
        name: name,
        color: color,
        sortOrder: i,
        createdAt: now,
        updatedAt: now,
      );
      await projects.upsert(project);

      if (name == _projectWithSubProjects) {
        for (var j = 0; j < _subProjectNames.length; j++) {
          await subProjects.upsert(SubProject(
            id: _uuid.v4(),
            projectId: project.id,
            name: _subProjectNames[j],
            sortOrder: j,
            createdAt: now,
            updatedAt: now,
          ));
        }
      }
    }
  }
}
