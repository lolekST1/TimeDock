import 'package:flutter/material.dart' hide HourFormat;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../core/ui/section_label.dart';
import '../../core/ui/td_card.dart';
import '../../core/ui/td_tokens.dart';
import '../../domain/services/csv_exporter.dart';
import '../../domain/services/export_config.dart';
import '../../domain/services/report_range.dart';
import '../../domain/services/worklog_exporter.dart';
import '../reports/report_providers.dart';
import '../settings/settings_controller.dart';
import 'export_providers.dart';

/// Export the selected report range to CSV, and manage local JSON backups.
/// The range mirrors the Reports screen selection.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  late HourFormat _hourFormat;
  late bool _roundTo15;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Seed from the saved export defaults; the user can still override per run.
    final settings = ref.read(settingsProvider);
    _hourFormat = settings.exportDecimalHours
        ? HourFormat.decimalHours
        : HourFormat.hoursMinutes;
    _roundTo15 = settings.exportRoundTo15;
  }

  ExportConfig get _config => ExportConfig(
        hourFormat: _hourFormat,
        rounding: _roundTo15
            ? const ExportRounding(increment: Duration(minutes: 15))
            : ExportRounding.none,
      );

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(reportRangeProvider);
    final period = ref.watch(reportPeriodProvider);

    final td = context.td;

    return Scaffold(
      appBar: AppBar(title: const Text('Eksport i kopie')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          // Range summary.
          TdCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: context.cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.date_range_rounded,
                      size: 19, color: context.cs.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Zakres · ${_periodName(period)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(_rangeText(range),
                          style: TextStyle(color: td.faint, fontSize: 12.5)),
                    ],
                  ),
                ),
                if (_busy)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const SectionLabel('Do rozliczenia'),
          _ExportAction(
            icon: Icons.receipt_long_rounded,
            title: 'Eksportuj worklog (JSON)',
            subtitle:
                'Zakończone sesje z Jira ID do aplikacji rozliczeniowej. '
                'Sesje bez Jira ID są pomijane i zliczane.',
            tone: _ExportTone.primary,
            onTap: _busy ? null : _exportWorklog,
          ),
          const SizedBox(height: 18),

          const SectionLabel('Zestawienia (CSV)'),
          _ExportAction(
            icon: Icons.table_rows_rounded,
            title: 'Sesje',
            subtitle: 'Jedna linia = jedna sesja.',
            onTap: _busy ? null : _exportPerSession,
          ),
          const SizedBox(height: 10),
          _ExportAction(
            icon: Icons.summarize_rounded,
            title: 'Podsumowanie',
            subtitle: 'Zsumowane per projekt/zadanie.',
            onTap: _busy ? null : _exportAggregated,
          ),
          const SizedBox(height: 18),

          const SectionLabel('Format'),
          TdCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  title: const Text('Godziny dziesiętne (1.25)'),
                  subtitle: const Text('Zamiast formatu 1:15'),
                  value: _hourFormat == HourFormat.decimalHours,
                  onChanged: (v) => setState(() => _hourFormat =
                      v ? HourFormat.decimalHours : HourFormat.hoursMinutes),
                ),
                SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  title: const Text('Zaokrąglaj do 15 minut w górę'),
                  subtitle:
                      const Text('Tylko w eksporcie; baza trzyma czas rzeczywisty'),
                  value: _roundTo15,
                  onChanged: (v) => setState(() => _roundTo15 = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          const SectionLabel('Kopia zapasowa'),
          _ExportAction(
            icon: Icons.save_rounded,
            title: 'Utwórz kopię (JSON)',
            subtitle: 'Pełny backup bazy, udostępniany z urządzenia.',
            onTap: _busy ? null : _backup,
          ),
          const SizedBox(height: 10),
          _ExportAction(
            icon: Icons.restore_rounded,
            title: 'Przywróć z ostatniej kopii',
            subtitle: 'Wczytuje najnowszy backup z katalogu aplikacji.',
            onTap: _busy ? null : _restoreLatest,
          ),
        ],
      ),
    );
  }

  /// Writes exports/backups to app-private storage, so the produced file is
  /// handed to the OS share sheet to actually leave the device.
  Future<void> _share(String path, String subject) =>
      ref.read(fileSharerProvider).shareFile(path, subject: subject);

  Future<void> _exportPerSession() async {
    await _run(() async {
      final range = ref.read(reportRangeProvider);
      final rows = await ref
          .read(exportBuilderProvider)
          .perSessionRows(widget.workspaceId, range);
      final csv = CsvExporter.perSession(rows, _config);
      final file = await ref
          .read(fileStoreProvider)
          .writeExport('timedock_sesje', 'csv', csv);
      await _share(file.path, 'TimeDock — sesje (CSV)');
      return 'Wyeksportowano ${rows.length} sesji (CSV).';
    });
  }

  Future<void> _exportAggregated() async {
    await _run(() async {
      final range = ref.read(reportRangeProvider);
      final rows = await ref
          .read(exportBuilderProvider)
          .aggregateRows(widget.workspaceId, range);
      final csv = CsvExporter.aggregated(rows, _config);
      final file = await ref
          .read(fileStoreProvider)
          .writeExport('timedock_podsumowanie', 'csv', csv);
      await _share(file.path, 'TimeDock — podsumowanie (CSV)');
      return 'Wyeksportowano podsumowanie (CSV).';
    });
  }

  Future<void> _exportWorklog() async {
    await _run(() async {
      final range = ref.read(reportRangeProvider);
      final result = await ref
          .read(worklogExportBuilderProvider)
          .worklogExport(widget.workspaceId, range,
              author: ref.read(settingsProvider).worklogAuthor);
      final skipped = result.skippedNoJira;
      final skippedNote = skipped == 0
          ? ''
          : '\nPominięto sesje bez Jira ID: $skipped — nie trafią do rozliczenia.';
      if (result.rows.isEmpty) {
        return skipped == 0
            ? 'Brak sesji do eksportu worklog.\nWłącz „Eksportuj do rozliczenia '
                'czasu" dla tej przestrzeni i uzupełnij Jira ID zadań.'
            : 'Nie wyeksportowano żadnej sesji.$skippedNote\n'
                'Uzupełnij Jira ID na zadaniach, aby trafiły do rozliczenia.';
      }
      final json = WorklogExporter.toJson(result.rows);
      final file = await ref
          .read(fileStoreProvider)
          .writeExport('timedock_worklog', 'json', json);
      await _share(file.path, 'TimeDock — worklog (JSON)');
      return 'Wyeksportowano ${result.rows.length} pozycji worklog.$skippedNote';
    });
  }

  Future<void> _backup() async {
    await _run(() async {
      final json = await ref.read(backupServiceProvider).exportToJson();
      final file = await ref.read(fileStoreProvider).writeBackup(json);
      await _share(file.path, 'TimeDock — kopia zapasowa (JSON)');
      return 'Utworzono kopię zapasową (JSON).';
    });
  }

  Future<void> _restoreLatest() async {
    await _run(() async {
      final backups = await ref.read(fileStoreProvider).listBackups();
      if (backups.isEmpty) return 'Brak kopii zapasowych do przywrócenia.';
      final json = await backups.first.readAsString();
      await ref.read(backupServiceProvider).importFromJson(json);
      return 'Przywrócono z:\n${backups.first.path}';
    });
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() => _busy = true);
    try {
      final message = await action();
      if (mounted) _snack(message);
    } catch (e) {
      if (mounted) _snack('Błąd: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _periodName(ReportPeriod p) => switch (p) {
        ReportPeriod.day => 'Dzień',
        ReportPeriod.week => 'Tydzień',
        ReportPeriod.month => 'Miesiąc',
        ReportPeriod.custom => 'Zakres',
      };

  String _rangeText(ReportRange r) => r.firstDay == r.lastDay
      ? formatIsoDate(r.firstDay)
      : '${formatIsoDate(r.firstDay)} – ${formatIsoDate(r.lastDay)}';
}

enum _ExportTone { neutral, primary }

/// A tappable export/backup action row: icon chip, title, subtitle and a
/// trailing share affordance. The primary tone highlights the worklog export.
class _ExportAction extends StatelessWidget {
  const _ExportAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.tone = _ExportTone.neutral,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final _ExportTone tone;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final primary = tone == _ExportTone.primary;
    final accent = context.cs.primary;
    return TdCard(
      padding: const EdgeInsets.all(14),
      color: primary ? context.cs.primaryContainer : null,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary ? accent : context.cs.primaryContainer,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon,
                  size: 21,
                  color: primary ? context.cs.onPrimary : accent),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(color: td.faint, fontSize: 12, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 20, color: td.faint),
          ],
        ),
      ),
    );
  }
}
