import 'package:uuid/uuid.dart';

import '../domain/entities/time_session.dart';
import '../domain/repositories/session_repository.dart';
import '../domain/services/session_editing.dart';
import '../domain/services/session_validator.dart';

/// Outcome of an edit/add attempt.
sealed class EditResult {
  const EditResult();
}

class EditSaved extends EditResult {
  const EditSaved(this.session);
  final TimeSession session;
}

/// The edit collided with sessions that can't be auto-trimmed (a neighbour
/// fully inside or fully containing the candidate). The UI must ask the user.
class EditConflict extends EditResult {
  const EditConflict(this.validation);
  final SessionValidation validation;
}

class EditInvalid extends EditResult {
  const EditInvalid(this.reason);
  final String reason;
}

/// Persists manual/edited sessions safely: validates against the day's other
/// sessions and, when the only conflicts are trimmable neighbours, applies the
/// proposed trims atomically alongside the edit.
class SessionEditor {
  SessionEditor(this._sessions, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final SessionRepository _sessions;
  final Uuid _uuid;

  /// Loads the neighbours that could overlap [candidate] (its own day, widened
  /// by a day on each side to catch midnight-crossing neighbours).
  Future<List<TimeSession>> _neighbours(TimeSession candidate) {
    final end = candidate.endUtc ?? candidate.startUtc;
    return _sessions.listOverlappingRange(
      candidate.workspaceId,
      candidate.startUtc.subtract(const Duration(days: 1)),
      end.add(const Duration(days: 1)),
    );
  }

  /// Saves an edited or new session. [force] applies the auto-trims even though
  /// the UI already saw them (used after a confirm), otherwise a fully-trimmable
  /// conflict is applied directly and only unresolvable conflicts surface.
  Future<EditResult> save(TimeSession candidate) async {
    if (candidate.endUtc == null) {
      return const EditInvalid('Sesja musi mieć koniec.');
    }
    final existing = await _neighbours(candidate);
    final validation = SessionValidator.validate(
      candidate: candidate,
      existing: existing,
    );
    if (!validation.startBeforeEnd) {
      return const EditInvalid('Początek musi być przed końcem.');
    }
    if (validation.isValid) {
      await _sessions.upsert(candidate);
      return EditSaved(candidate);
    }
    if (validation.isAutoResolvable) {
      await _sessions.upsertAll([candidate, ...validation.proposedTrims]);
      return EditSaved(candidate);
    }
    return EditConflict(validation);
  }

  /// Builds a new manual session for [context] over [startUtc]..[endUtc].
  TimeSession buildManual({
    required SessionContext context,
    required DateTime startUtc,
    required DateTime endUtc,
    required int startOffsetMinutes,
    required int endOffsetMinutes,
    String? comment,
    required DateTime nowUtc,
  }) {
    return TimeSession(
      id: _uuid.v4(),
      workspaceId: context.workspaceId,
      projectId: context.projectId,
      subProjectId: context.subProjectId,
      taskId: context.taskId,
      startUtc: startUtc,
      endUtc: endUtc,
      startOffsetMinutes: startOffsetMinutes,
      endOffsetMinutes: endOffsetMinutes,
      comment: comment,
      isManuallyAdded: true,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );
  }

  /// Splits a finished session at [atUtc] and persists both halves.
  Future<void> split(
    TimeSession session, {
    required DateTime atUtc,
    required int atOffsetMinutes,
    required DateTime nowUtc,
  }) async {
    final (first, second) = SessionEditing.split(
      session,
      atUtc: atUtc,
      newId: _uuid.v4(),
      atOffsetMinutes: atOffsetMinutes,
      nowUtc: nowUtc,
    );
    await _sessions.upsertAll([first, second]);
  }

  Future<void> delete(String id) => _sessions.delete(id);
}
