import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timedock/data/db/database.dart';
import 'package:timedock/data/providers.dart';
import 'package:timedock/data/repositories/drift_workspace_repository.dart';
import 'package:timedock/domain/entities/workspace.dart';
import 'package:timedock/features/app_state/app_providers.dart';
import 'package:timedock/features/settings/settings_controller.dart';
import 'package:timedock/features/settings/settings_screen.dart';

void main() {
  testWidgets('toggling an export default persists the setting',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final db = TimeDockDatabase(DatabaseConnection(NativeDatabase.memory()));
    addTearDown(db.close);
    final now = DateTime.utc(2026, 7, 10);
    await DriftWorkspaceRepository(db).upsert(Workspace(
        id: 'w1', name: 'Absysco', colorSeed: 0xFF1565C0, createdAt: now, updatedAt: now));

    final container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).exportDecimalHours, isFalse);

    await tester.tap(find.text('Godziny dziesiętne'));
    await tester.pumpAndSettle();

    expect(container.read(settingsProvider).exportDecimalHours, isTrue);
    expect(prefs.getBool('export_decimal_hours'), isTrue);

    // The seeded workspace is listed.
    expect(find.text('Absysco'), findsOneWidget);
  });
}
