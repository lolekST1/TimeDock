import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/data/db/database.dart';
import 'package:timedock/data/providers.dart';
import 'package:timedock/data/repositories/drift_project_repository.dart';
import 'package:timedock/data/repositories/drift_workspace_repository.dart';
import 'package:timedock/domain/entities/project.dart';
import 'package:timedock/domain/entities/time_session.dart';
import 'package:timedock/domain/entities/workspace.dart';
import 'package:timedock/features/history/session_editor_screen.dart';

void main() {
  testWidgets('editing an end time with the +15 chip saves the new end',
      (tester) async {
    final db = TimeDockDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);

    final day = DateTime.utc(2026, 7, 10);
    await DriftWorkspaceRepository(db).upsert(Workspace(
        id: 'w1', name: 'Absysco', colorSeed: 0xFF1565C0, createdAt: day, updatedAt: day));
    await DriftProjectRepository(db).upsert(Project(
        id: 'p1', workspaceId: 'w1', name: 'Danone', color: 0xFF1E88E5, createdAt: day, updatedAt: day));

    // A finished session 08:00–09:00 local.
    final start = DateTime(2026, 7, 10, 8);
    final existing = TimeSession(
      id: 's1',
      workspaceId: 'w1',
      projectId: 'p1',
      startUtc: start.toUtc(),
      endUtc: start.add(const Duration(hours: 1)).toUtc(),
      startOffsetMinutes: start.timeZoneOffset.inMinutes,
      endOffsetMinutes: start.timeZoneOffset.inMinutes,
      createdAt: day,
      updatedAt: day,
    );

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    await container.read(sessionRepositoryProvider).upsert(existing);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: SessionEditorScreen(workspaceId: 'w1', existing: existing),
      ),
    ));
    await tester.pumpAndSettle();

    // Bump the end by 15 minutes and save.
    await tester.tap(find.byTooltip('+15 min'));
    await tester.pump();
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();

    final saved = (await container
            .read(sessionRepositoryProvider)
            .listOverlappingRange('w1', day, day.add(const Duration(days: 1))))
        .firstWhere((s) => s.id == 's1');
    expect(saved.duration, const Duration(hours: 1, minutes: 15));
    expect(saved.wasEdited, isTrue);
  });
}
