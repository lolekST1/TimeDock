import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/export_config.dart';
import '../../domain/services/forgotten_timer.dart';
import '../app_state/app_providers.dart';

/// User-configurable app settings, persisted in SharedPreferences. Kept small
/// and global for now; the forgotten-timer settings map to the domain type.
class AppSettings {
  const AppSettings({
    this.forgottenTimerEnabled = true,
    this.forgottenTimerThresholdMinutes = 240,
    this.exportDecimalHours = false,
    this.exportRoundTo15 = false,
    this.themeMode = ThemeMode.system,
  });

  final bool forgottenTimerEnabled;
  final int forgottenTimerThresholdMinutes;
  final bool exportDecimalHours;
  final bool exportRoundTo15;
  final ThemeMode themeMode;

  ForgottenTimerSettings get forgottenTimer => ForgottenTimerSettings(
        enabled: forgottenTimerEnabled,
        threshold: Duration(minutes: forgottenTimerThresholdMinutes),
      );

  ExportConfig exportConfig({String csvSeparator = ','}) => ExportConfig(
        csvSeparator: csvSeparator,
        hourFormat:
            exportDecimalHours ? HourFormat.decimalHours : HourFormat.hoursMinutes,
        rounding: exportRoundTo15
            ? const ExportRounding(increment: Duration(minutes: 15))
            : ExportRounding.none,
      );

  AppSettings copyWith({
    bool? forgottenTimerEnabled,
    int? forgottenTimerThresholdMinutes,
    bool? exportDecimalHours,
    bool? exportRoundTo15,
    ThemeMode? themeMode,
  }) {
    return AppSettings(
      forgottenTimerEnabled:
          forgottenTimerEnabled ?? this.forgottenTimerEnabled,
      forgottenTimerThresholdMinutes: forgottenTimerThresholdMinutes ??
          this.forgottenTimerThresholdMinutes,
      exportDecimalHours: exportDecimalHours ?? this.exportDecimalHours,
      exportRoundTo15: exportRoundTo15 ?? this.exportRoundTo15,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

class SettingsController extends Notifier<AppSettings> {
  static const _kEnabled = 'forgotten_timer_enabled';
  static const _kThresholdMinutes = 'forgotten_timer_threshold_minutes';
  static const _kLegacyThresholdHours = 'forgotten_timer_threshold_hours';
  static const _kDecimal = 'export_decimal_hours';
  static const _kRound = 'export_round_15';
  static const _kThemeMode = 'theme_mode';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    const defaults = AppSettings();
    // Migration: the threshold used to be stored in hours.
    final legacyHours = prefs.getInt(_kLegacyThresholdHours);
    return AppSettings(
      forgottenTimerEnabled:
          prefs.getBool(_kEnabled) ?? defaults.forgottenTimerEnabled,
      forgottenTimerThresholdMinutes: prefs.getInt(_kThresholdMinutes) ??
          (legacyHours != null
              ? legacyHours * 60
              : defaults.forgottenTimerThresholdMinutes),
      exportDecimalHours:
          prefs.getBool(_kDecimal) ?? defaults.exportDecimalHours,
      exportRoundTo15: prefs.getBool(_kRound) ?? defaults.exportRoundTo15,
      themeMode: _themeModeFromString(prefs.getString(_kThemeMode)),
    );
  }

  static ThemeMode _themeModeFromString(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref.read(sharedPreferencesProvider).setString(_kThemeMode, mode.name);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setForgottenTimerEnabled(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_kEnabled, value);
    state = state.copyWith(forgottenTimerEnabled: value);
  }

  Future<void> setForgottenTimerThresholdMinutes(int minutes) async {
    final clamped = minutes.clamp(5, 24 * 60);
    await ref
        .read(sharedPreferencesProvider)
        .setInt(_kThresholdMinutes, clamped);
    state = state.copyWith(forgottenTimerThresholdMinutes: clamped);
  }

  Future<void> setExportDecimalHours(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_kDecimal, value);
    state = state.copyWith(exportDecimalHours: value);
  }

  Future<void> setExportRoundTo15(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(_kRound, value);
    state = state.copyWith(exportRoundTo15: value);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);
