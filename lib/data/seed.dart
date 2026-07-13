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

  static const _absyscoProjects = [
    ('Danone', 0xFF1E88E5),
    ('Carlsberg', 0xFF2E7D32),
    ('PMI', 0xFF6D4C41),
    ('MSS', 0xFF8E24AA),
    ('KP', 0xFFF4511E),
    ('XBS', 0xFF00897B),
    ('MerService', 0xFF3949AB),
    ('Cursor', 0xFF546E7A),
    ('ProPeople', 0xFFD81B60),
  ];

  static const _carlsbergSubProjects = ['TT', 'LF', 'CC', 'Dyskonty'];

  /// Seeds initial data if (and only if) the database is empty.
  /// Idempotent: safe to call on every app start.
  Future<void> seedIfEmpty() async {
    if (await workspaces.hasAny()) return;
    final now = _nowUtc();

    final absysco = Workspace(
      id: _uuid.v4(),
      name: 'Absysco',
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
    await workspaces.upsert(absysco);
    await workspaces.upsert(private);

    for (var i = 0; i < _absyscoProjects.length; i++) {
      final (name, color) = _absyscoProjects[i];
      final project = Project(
        id: _uuid.v4(),
        workspaceId: absysco.id,
        name: name,
        color: color,
        sortOrder: i,
        createdAt: now,
        updatedAt: now,
      );
      await projects.upsert(project);

      if (name == 'Carlsberg') {
        for (var j = 0; j < _carlsbergSubProjects.length; j++) {
          await subProjects.upsert(SubProject(
            id: _uuid.v4(),
            projectId: project.id,
            name: _carlsbergSubProjects[j],
            sortOrder: j,
            createdAt: now,
            updatedAt: now,
          ));
        }
      }
    }
  }
}
