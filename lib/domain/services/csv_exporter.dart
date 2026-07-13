import 'export_config.dart';

/// A fully name-resolved row for export. Building these from ids/names is the
/// caller's job, keeping the serializer pure and testable.
class ExportRow {
  const ExportRow({
    required this.date,
    required this.start,
    required this.end,
    required this.duration,
    required this.workspace,
    required this.project,
    this.subProject,
    this.task,
    this.jiraId,
    this.comment,
  });

  final String date; // yyyy-MM-dd
  final String start; // HH:mm
  final String end; // HH:mm
  final Duration duration;
  final String workspace;
  final String project;
  final String? subProject;
  final String? task;
  final String? jiraId;
  final String? comment;
}

/// One aggregated line (project/sub-project/task) of a report export.
class AggregateRow {
  const AggregateRow({
    required this.project,
    this.subProject,
    this.task,
    this.jiraId,
    required this.total,
    required this.sessionCount,
  });

  final String project;
  final String? subProject;
  final String? task;
  final String? jiraId;
  final Duration total;
  final int sessionCount;
}

abstract final class CsvExporter {
  static const _perSessionHeader = [
    'Data', 'Start', 'Koniec', 'Czas', 'Workspace', 'Projekt',
    'Podprojekt', 'Zadanie', 'Jira', 'Komentarz',
  ];

  static const _aggregateHeader = [
    'Projekt', 'Podprojekt', 'Zadanie', 'Jira', 'Czas', 'Liczba sesji',
  ];

  /// One line per session.
  static String perSession(List<ExportRow> rows, ExportConfig config) {
    final buffer = StringBuffer()
      ..writeln(_join(_perSessionHeader, config));
    for (final r in rows) {
      buffer.writeln(_join([
        r.date,
        r.start,
        r.end,
        config.formatDuration(r.duration),
        r.workspace,
        r.project,
        r.subProject ?? '',
        r.task ?? '',
        r.jiraId ?? '',
        r.comment ?? '',
      ], config));
    }
    return buffer.toString();
  }

  /// One line per aggregated project/sub-project/task — the client-facing
  /// summary.
  static String aggregated(List<AggregateRow> rows, ExportConfig config) {
    final buffer = StringBuffer()
      ..writeln(_join(_aggregateHeader, config));
    for (final r in rows) {
      buffer.writeln(_join([
        r.project,
        r.subProject ?? '',
        r.task ?? '',
        r.jiraId ?? '',
        config.formatDuration(r.total),
        r.sessionCount.toString(),
      ], config));
    }
    return buffer.toString();
  }

  static String _join(List<String> fields, ExportConfig config) =>
      fields.map((f) => _escape(f, config.csvSeparator)).join(config.csvSeparator);

  /// RFC-4180 escaping: quote fields containing the separator, quotes or
  /// newlines, doubling embedded quotes.
  static String _escape(String field, String separator) {
    final needsQuote = field.contains(separator) ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r');
    if (!needsQuote) return field;
    return '"${field.replaceAll('"', '""')}"';
  }
}
