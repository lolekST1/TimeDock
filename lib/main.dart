import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/providers.dart';
import 'data/services/android_timer_foreground_service.dart';
import 'features/app_state/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final overrides = <Override>[
    sharedPreferencesProvider.overrideWithValue(prefs),
  ];
  if (Platform.isAndroid) {
    overrides.add(timerForegroundServiceProvider
        .overrideWithValue(AndroidTimerForegroundService()));
  }

  final container = ProviderContainer(overrides: overrides);
  await container.read(seederProvider).seedIfEmpty();

  if (Platform.isAndroid) {
    // Bridge the notification STOP button (fired from the service isolate)
    // to the main isolate, which stops the timer through the database.
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.addTaskDataCallback((data) {
      if (data == 'stop') {
        container.read(timerServiceProvider).stop();
      }
    });
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TimeDockApp(),
    ),
  );
}
