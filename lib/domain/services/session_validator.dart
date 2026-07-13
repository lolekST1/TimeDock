import '../entities/time_session.dart';

/// Result of validating a manually added or edited session against its
/// neighbours. Live timer sessions can never overlap (there is only one
/// active timer), so this guards the only door overlaps can enter through.
class SessionValidation {
  const SessionValidation({
    required this.startBeforeEnd,
    required this.conflicts,
    required this.proposedTrims,
    required this.unresolvable,
  });

  final bool startBeforeEnd;

  /// Existing sessions the candidate overlaps with.
  final List<TimeSession> conflicts;

  /// Trimmed copies of conflicting neighbours: applying these updates
  /// alongside the candidate removes every resolvable overlap. A neighbour
  /// overlapping only at its end gets its end pulled back to the candidate's
  /// start; one overlapping only at its start gets pushed to the candidate's
  /// end.
  final List<TimeSession> proposedTrims;

  /// Conflicts that cannot be fixed by trimming: neighbours fully inside the
  /// candidate (they would vanish) or fully containing it (they would need
  /// splitting). These require an explicit user decision.
  final List<TimeSession> unresolvable;

  bool get isValid => startBeforeEnd && conflicts.isEmpty;

  bool get isAutoResolvable =>
      startBeforeEnd && unresolvable.isEmpty;
}

abstract final class SessionValidator {
  /// Validates [candidate] (finished session with concrete start and end)
  /// against [existing] sessions. The candidate itself, running sessions
  /// being replaced, etc. must be excluded by the caller; any session in
  /// [existing] sharing the candidate's id is skipped defensively.
  static SessionValidation validate({
    required TimeSession candidate,
    required Iterable<TimeSession> existing,
    DateTime? nowUtc,
  }) {
    final start = candidate.startUtc;
    final end = candidate.endUtc ?? nowUtc;
    if (end == null) {
      throw ArgumentError('running candidate requires nowUtc');
    }
    final startBeforeEnd = start.isBefore(end);

    final conflicts = <TimeSession>[];
    final trims = <TimeSession>[];
    final unresolvable = <TimeSession>[];

    if (startBeforeEnd) {
      for (final other in existing) {
        if (other.id == candidate.id) continue;
        final otherEnd = other.endUtc ?? nowUtc;
        if (otherEnd == null) continue;
        final overlaps = start.isBefore(otherEnd) && other.startUtc.isBefore(end);
        if (!overlaps) continue;
        conflicts.add(other);

        final startsBefore = other.startUtc.isBefore(start);
        final endsAfter = otherEnd.isAfter(end);
        if (startsBefore && !endsAfter) {
          trims.add(other.copyWith(
            endUtc: start,
            endOffsetMinutes: candidate.startOffsetMinutes,
            wasEdited: true,
          ));
        } else if (!startsBefore && endsAfter) {
          trims.add(other.copyWith(
            startUtc: end,
            startOffsetMinutes:
                candidate.endOffsetMinutes ?? candidate.startOffsetMinutes,
            wasEdited: true,
          ));
        } else {
          // Fully contained in the candidate, or fully containing it.
          unresolvable.add(other);
        }
      }
    }

    return SessionValidation(
      startBeforeEnd: startBeforeEnd,
      conflicts: conflicts,
      proposedTrims: trims,
      unresolvable: unresolvable,
    );
  }
}
