import 'package:flutter/material.dart' hide HourFormat;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Eksport i kopie zapasowe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Zakres eksportu', style: Theme.of(context).textTheme.titleMedium),
          Text('${_periodName(period)} · ${_rangeText(range)}'),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Godziny dziesiętne (1.25)'),
            subtitle: const Text('Zamiast formatu 1:15'),
            value: _hourFormat == HourFormat.decimalHours,
            onChanged: (v) => setState(() => _hourFormat =
                v ? HourFormat.decimalHours : HourFormat.hoursMinutes),
          ),
          SwitchListTile(
            title: const Text('Zaokrąglaj do 15 minut w górę'),
            subtitle: const Text('Tylko w eksporcie; baza trzyma czas rzeczywisty'),
            value: _roundTo15,
            onChanged: (v) => setState(() => _roundTo15 = v),
          ),
          const Divider(height: 32),
          FilledButton.icon(
            onPressed: _busy ? null : _exportPerSession,
            icon: const Icon(Icons.table_rows_outlined),
            label: const Text('Eksportuj sesje (CSV)'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _exportAggregated,
            icon: const Icon(Icons.summarize_outlined),
            label: const Text('Eksportuj podsumowanie (CSV)'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _exportWorklog,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Eksportuj worklog (JSON)'),
          ),
          const Divider(height: 32),
          Text('Kopia zapasowa', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _backup,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Utwórz kopię zapasową (JSON)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _restoreLatest,
            icon: const Icon(Icons.restore),
            label: const Text('Przywróć z ostatniej kopii'),
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
