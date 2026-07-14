import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timedock/domain/services/export_config.dart';
import 'package:timedock/features/app_state/app_providers.dart';
import 'package:timedock/features/settings/settings_controller.dart';

Future<ProviderContainer> _container(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
  ]);
}

void main() {
  test('defaults when nothing is stored', () async {
    final container = await _container({});
    addTearDown(container.dispose);
    final s = container.read(settingsProvider);
    expect(s.forgottenTimerEnabled, isTrue);
    expect(s.forgottenTimerThresholdHours, 4);
    expect(s.exportDecimalHours, isFalse);
    expect(s.exportRoundTo15, isFalse);
  });

  test('reads stored values', () async {
    final container = await _container({
      'forgotten_timer_enabled': false,
      'forgotten_timer_threshold_hours': 8,
      'export_decimal_hours': true,
      'export_round_15': true,
    });
    addTearDown(container.dispose);
    final s = container.read(settingsProvider);
    expect(s.forgottenTimerEnabled, isFalse);
    expect(s.forgottenTimerThresholdHours, 8);
    expect(s.exportDecimalHours, isTrue);
    expect(s.exportRoundTo15, isTrue);
  });

  test('setters persist and update state', () async {
    final container = await _container({});
    addTearDown(container.dispose);
    final controller = container.read(settingsProvider.notifier);

    await controller.setForgottenTimerThresholdHours(6);
    await controller.setForgottenTimerEnabled(false);
    await controller.setExportDecimalHours(true);

    final s = container.read(settingsProvider);
    expect(s.forgottenTimerThresholdHours, 6);
    expect(s.forgottenTimerEnabled, isFalse);
    expect(s.exportDecimalHours, isTrue);

    // Persisted: a fresh controller over the same prefs sees the values.
    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getInt('forgotten_timer_threshold_hours'), 6);
    expect(prefs.getBool('forgotten_timer_enabled'), isFalse);
  });

  test('threshold is clamped to a sane range', () async {
    final container = await _container({});
    addTearDown(container.dispose);
    final controller = container.read(settingsProvider.notifier);
    await controller.setForgottenTimerThresholdHours(0);
    expect(container.read(settingsProvider).forgottenTimerThresholdHours, 1);
    await controller.setForgottenTimerThresholdHours(48);
    expect(container.read(settingsProvider).forgottenTimerThresholdHours, 24);
  });

  test('theme mode defaults to system and persists a choice', () async {
    final container = await _container({});
    addTearDown(container.dispose);
    expect(container.read(settingsProvider).themeMode, ThemeMode.system);

    await container.read(settingsProvider.notifier).setThemeMode(ThemeMode.light);
    expect(container.read(settingsProvider).themeMode, ThemeMode.light);
    expect(container.read(sharedPreferencesProvider).getString('theme_mode'),
        'light');
  });

  test('reads a stored theme mode', () async {
    final container = await _container({'theme_mode': 'dark'});
    addTearDown(container.dispose);
    expect(container.read(settingsProvider).themeMode, ThemeMode.dark);
  });

  test('maps to domain forgotten-timer and export config', () async {
    final container = await _container({
      'forgotten_timer_threshold_hours': 3,
      'export_decimal_hours': true,
      'export_round_15': true,
    });
    addTearDown(container.dispose);
    final s = container.read(settingsProvider);

    expect(s.forgottenTimer.threshold, const Duration(hours: 3));
    final config = s.exportConfig();
    expect(config.hourFormat, HourFormat.decimalHours);
    expect(config.rounding.increment, const Duration(minutes: 15));
  });
}
