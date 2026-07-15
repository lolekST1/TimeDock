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
        // STOP on the notification / widget while the app is alive.
        onStopRequested: () => reconcilePendingActions(container),
        // Start/switch from the widget while the app is alive.
        onStartRequested: () => reconcilePendingActions(container),
      ),
    ));
    overrides.add(reminderSchedulerProvider
        .overrideWithValue(AndroidReminderScheduler()));
  }

  container = ProviderContainer(overrides: overrides);
  await container.read(seederProvider).seedIfEmpty();
  await reconcilePendingActions(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TimeDockApp(),
    ),
  );
}

/// Reconciles the database (the source of truth) with widget/notification
/// actions taken while the app was frozen or dead: a pending start/switch (from
/// tapping a widget tile) and/or a pending stop (from the STOP button).
///
/// Both are consumed here and applied in CHRONOLOGICAL order, which matters
/// when both happened: stopping one timer then starting another must close the
/// first at its stop instant before opening the second — applying the stop last
/// would instead close the freshly started timer and lose it.
Future<void> reconcilePendingActions(ProviderContainer container) async {
  final service = container.read(timerForegroundServiceProvider);
  final timer = container.read(timerServiceProvider);
  final start = await service.takePendingStart();
  final stop = await service.takePendingStop();

  Future<void> applyStart() async {
    if (start == null) return;
    // A fresh start: startAt stops and saves any running session first.
    await timer.startAt(start.context, start.startUtc);
  }

  Future<void> applyStop() async {
    if (stop == null) return;
    await timer.stopAt(stop);
  }

  if (start != null && stop != null && stop.isBefore(start.startUtc)) {
    await applyStop();
    await applyStart();
  } else {
    await applyStart();
    await applyStop();
  }
}
