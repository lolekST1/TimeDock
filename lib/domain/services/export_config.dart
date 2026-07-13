/// How durations are rendered in an export.
enum HourFormat {
  /// `1:15` — hours and minutes.
  hoursMinutes,

  /// `1.25` — decimal hours (with [ExportConfig.csvSeparator]-safe decimal
  /// mark controlled by [ExportConfig.decimalComma]).
  decimalHours,
}

/// Rounding applied only at export time; the database always keeps real time.
class ExportRounding {
  const ExportRounding({required this.increment, this.roundUp = true});

  /// e.g. 15 minutes. [Duration.zero] means no rounding.
  final Duration increment;

  /// Round up (ceil) when true — the common billing convention; otherwise
  /// round to nearest.
  final bool roundUp;

  static const none = ExportRounding(increment: Duration.zero);

  Duration apply(Duration value) {
    if (increment.inSeconds <= 0) return value;
    final unit = increment.inSeconds;
    final secs = value.inSeconds;
    if (roundUp) {
      final units = (secs + unit - 1) ~/ unit;
      return Duration(seconds: units * unit);
    }
    final units = ((secs / unit) + 0.5).floor();
    return Duration(seconds: units * unit);
  }
}

class ExportConfig {
  const ExportConfig({
    this.csvSeparator = ',',
    this.hourFormat = HourFormat.hoursMinutes,
    this.decimalComma = false,
    this.rounding = ExportRounding.none,
  });

  final String csvSeparator;
  final HourFormat hourFormat;

  /// Use a comma as the decimal mark (Polish locale). Ignored unless
  /// [hourFormat] is [HourFormat.decimalHours]; forced off when the CSV
  /// separator is itself a comma to avoid ambiguity.
  final bool decimalComma;

  final ExportRounding rounding;

  String formatDuration(Duration raw) {
    final d = rounding.apply(raw);
    switch (hourFormat) {
      case HourFormat.hoursMinutes:
        final h = d.inHours;
        final m = (d.inMinutes % 60).toString().padLeft(2, '0');
        return '$h:$m';
      case HourFormat.decimalHours:
        final hours = d.inSeconds / 3600.0;
        var text = hours.toStringAsFixed(2);
        if (decimalComma && csvSeparator != ',') {
          text = text.replaceAll('.', ',');
        }
        return text;
    }
  }
}
