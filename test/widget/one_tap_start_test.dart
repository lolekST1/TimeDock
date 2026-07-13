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
import 'package:timedock/domain/entities/workspace.dart';
import 'package:timedock/features/app_state/app_providers.dart';
import 'package:timedock/features/home/home_screen.dart';

void main() {
  testWidgets('tapping a project starts the timer in one tap', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final db = TimeDockDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);

    final now = DateTime.utc(2026, 7, 10, 8);
    await DriftWorkspaceRepository(db).upsert(Workspace(
        id: 'w1', name: 'Absysco', colorSeed: 0xFF1565C0, createdAt: now, updatedAt: now));
    await DriftProjectRepository(db).upsert(Project(
        id: 'p1',
        workspaceId: 'w1',
        name: 'Danone',
        color: 0xFF1E88E5,
        createdAt: now,
        updatedAt: now));

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();

    // No timer running yet.
    expect(await container.read(sessionRepositoryProvider).getActive(), isNull);

    // One tap on the project tile.
    await tester.tap(find.text('Danone'));
    await tester.pump();

    final active = await container.read(sessionRepositoryProvider).getActive();
    expect(active, isNotNull);
    expect(active!.projectId, 'p1');
    expect(active.isRunning, isTrue);

    // The active-timer bar (with STOP) is now shown.
    await tester.pumpAndSettle();
    expect(find.text('STOP'), findsOneWidget);
  });
}
