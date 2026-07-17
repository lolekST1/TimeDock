import 'dart:convert';

/// A fully resolved worklog entry, one per finished session, ready to be
/// serialized for the downstream timesheet application (the future Tempo
/// replacement). Building these — and applying the business filters — is the
/// caller's job, keeping the serializer pure and unaware of those rules,
/// exactly like [ExportRow] for the CSV export.
class WorklogRow {
  const WorklogRow({
    required this.sessionId,
    required this.issueKey,
    required this.startUtc,
    required this.endUtc,
    required this.durationSeconds,
    this.description,
    required this.workspace,
    this.author,
  });

  /// Session UUID — the idempotency key on the consuming side.
  final String sessionId;

  /// The task's Jira id (e.g. `PROJ-123`); guaranteed non-empty by the builder.
  final String issueKey;

  /// Session start, in UTC.
  final DateTime startUtc;

  /// Session end, in UTC. Only finished sessions are exported.
  final DateTime endUtc;

  final int durationSeconds;

  /// The session comment; may be null or empty.
  final String? description;

  /// Workspace name, informational only.
  final String workspace;

  /// Who logged the time — the single configured worklog author for this
  /// installation (TimeDock is a personal tool; there is no user model).
  /// May be null when no author is configured.
  final String? author;

  Map<String, Object?> toJson() => {
        'sessionId': sessionId,
        'issueKey': issueKey,
        'startUtc': _iso(startUtc),
        'endUtc': _iso(endUtc),
        'durationSeconds': durationSeconds,
        'description': description,
        'workspace': workspace,
        'author': author,
      };

  /// ISO-8601 in UTC with a trailing `Z` (e.g. `2026-07-16T08:00:00.000Z`).
  static String _iso(DateTime dt) => dt.toUtc().toIso8601String();
}

/// Serializes worklog rows to the JSON payload consumed downstream: a list of
/// objects, one per session. Pure and stateless, mirroring [CsvExporter].
abstract final class WorklogExporter {
  /// A JSON array of worklog objects, pretty-printed for readability.
  static String toJson(List<WorklogRow> rows) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(rows.map((r) => r.toJson()).toList());
  }
}
