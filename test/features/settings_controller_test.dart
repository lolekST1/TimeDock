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
    expect(s.forgottenTimerThresholdMinutes, 240);
    expect(s.exportDecimalHours, isFalse);
    expect(s.exportRoundTo15, isFalse);
  });

  test('reads stored values', () async {
    final container = await _container({
      'forgotten_timer_enabled': false,
      'forgotten_timer_threshold_minutes': 30,
      'export_decimal_hours': true,
      'export_round_15': true,
    });
    addTearDown(container.dispose);
    final s = container.read(settingsProvider);
    expect(s.forgottenTimerEnabled, isFalse);
    expect(s.forgottenTimerThresholdMinutes, 30);
    expect(s.exportDecimalHours, isTrue);
    expect(s.exportRoundTo15, isTrue);
  });

  test('setters persist and update state', () async {
    final container = await _container({});
    addTearDown(container.dispose);
    final controller = container.read(settingsProvider.notifier);

    await controller.setForgottenTimerThresholdMinutes(90);
    await controller.setForgottenTimerEnabled(false);
    await controller.setExportDecimalHours(true);

    final s = container.read(settingsProvider);
    expect(s.forgottenTimerThresholdMinutes, 90);
    expect(s.forgottenTimerEnabled, isFalse);
    expect(s.exportDecimalHours, isTrue);

    // Persisted: a fresh controller over the same prefs sees the values.
    final prefs = container.read(sharedPreferencesProvider);
    expect(prefs.getInt('forgotten_timer_threshold_minutes'), 90);
    expect(prefs.getBool('forgotten_timer_enabled'), isFalse);
  });

  test('threshold is clamped to a sane range', () async {
    final container = await _container({});
    addTearDown(container.dispose);
    final controller = container.read(settingsProvider.notifier);
    await controller.setForgottenTimerThresholdMinutes(1);
    expect(container.read(settingsProvider).forgottenTimerThresholdMinutes, 5);
    await controller.setForgottenTimerThresholdMinutes(48 * 60);
    expect(container.read(settingsProvider).forgottenTimerThresholdMinutes,
        24 * 60);
  });

  test('migrates a legacy hours value to minutes', () async {
    final container =
        await _container({'forgotten_timer_threshold_hours': 2});
    addTearDown(container.dispose);
    expect(
        container.read(settingsProvider).forgottenTimerThresholdMinutes, 120);
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
      'forgotten_timer_threshold_minutes': 45,
      'export_decimal_hours': true,
      'export_round_15': true,
    });
    addTearDown(container.dispose);
    final s = container.read(settingsProvider);

    expect(s.forgottenTimer.threshold, const Duration(minutes: 45));
    final config = s.exportConfig();
    expect(config.hourFormat, HourFormat.decimalHours);
    expect(config.rounding.increment, const Duration(minutes: 15));
  });
}
