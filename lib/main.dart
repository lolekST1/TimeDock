import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'app.dart';
import 'data/providers.dart';
import 'data/services/android_timer_foreground_service.dart';
import 'data/services/reminder_scheduler.dart';
import 'features/app_state/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  final prefs = await SharedPreferences.getInstance();

  // The service's STOP callback needs the container that is created below;
  // `late` lets the closure capture it before it exists.
  late final ProviderContainer container;

  final overrides = <Override>[
    sharedPreferencesProvider.overrideWithValue(prefs),
  ];
  if (Platform.isAndroid) {
    overrides.add(timerForegroundServiceProvider.overrideWithValue(
      AndroidTimerForegroundService(
        // STOP on the notification while the app is alive.
        onStopRequested: () => container.read(timerServiceProvider).stop(),
        // Start from the widget/tile while the app is alive.
        onStartRequested: () => applyPendingStart(container),
      ),
    ));
    overrides.add(reminderSchedulerProvider
        .overrideWithValue(AndroidReminderScheduler()));
  }

  container = ProviderContainer(overrides: overrides);
  await container.read(seederProvider).seedIfEmpty();
  await applyPendingStart(container);
  await applyPendingStop(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TimeDockApp(),
    ),
  );
}

/// If a timer was started from the widget/tile while the app was frozen or
/// dead, create the session at the exact recorded instant. The native side
/// already showed the notification/foreground service; this makes the database
/// (the source of truth) match.
Future<void> applyPendingStart(ProviderContainer container) async {
  final pending =
      await container.read(timerForegroundServiceProvider).takePendingStart();
  if (pending == null) return;
  final timer = container.read(timerServiceProvider);
  if (pending.switchOnly) {
    // A timer was running: switch its context in place, keeping the clock.
    final switched = await timer.switchContext(pending.context);
    if (switched != null) return;
    // Nothing was running after all — fall through to a normal start.
  }
  await timer.startAt(pending.context, pending.startUtc);
}

/// If STOP was pressed on the notification while the app was frozen or dead,
/// close the session at the exact recorded instant.
Future<void> applyPendingStop(ProviderContainer container) async {
  final pending =
      await container.read(timerForegroundServiceProvider).takePendingStop();
  if (pending == null) return;
  await container.read(timerServiceProvider).stopAt(pending);
}
