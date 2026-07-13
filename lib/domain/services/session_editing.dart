import '../entities/time_session.dart';

/// Pure helpers for splitting and building sessions during editing. Kept free
/// of id/clock generation so they stay deterministic and testable; callers
/// supply new ids and offsets.
abstract final class SessionEditing {
  /// Splits [session] at [atUtc] into two adjacent sessions covering the same
  /// span. The first keeps the original id, comment and context; the second
  /// gets [newId], the same context and no comment (the user annotates it).
  /// Both are flagged edited. Throws if [atUtc] is not strictly inside.
  static (TimeSession first, TimeSession second) split(
    TimeSession session, {
    required DateTime atUtc,
    required String newId,
    required int atOffsetMinutes,
    required DateTime nowUtc,
  }) {
    final end = session.endUtc;
    if (end == null) {
      throw ArgumentError('cannot split a running session');
    }
    if (!atUtc.isAfter(session.startUtc) || !atUtc.isBefore(end)) {
      throw ArgumentError('split point must be strictly inside the session');
    }

    final first = session.copyWith(
      endUtc: atUtc,
      endOffsetMinutes: atOffsetMinutes,
      wasEdited: true,
      updatedAt: nowUtc,
    );
    final second = TimeSession(
      id: newId,
      workspaceId: session.workspaceId,
      projectId: session.projectId,
      subProjectId: session.subProjectId,
      taskId: session.taskId,
      startUtc: atUtc,
      endUtc: end,
      startOffsetMinutes: atOffsetMinutes,
      endOffsetMinutes: session.endOffsetMinutes,
      wasEdited: true,
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );
    return (first, second);
  }
}
