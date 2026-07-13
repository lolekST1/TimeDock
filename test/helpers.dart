import 'package:timedock/domain/entities/time_session.dart';

/// Builds a finished (or running, when [end] is null) session with sensible
/// defaults so tests only spell out what they assert on.
TimeSession session({
  String id = 's1',
  String workspaceId = 'w1',
  String projectId = 'p1',
  String? subProjectId,
  String? taskId,
  required DateTime start,
  DateTime? end,
  int startOffset = 0,
  int? endOffset,
  String? comment,
  bool isManuallyAdded = false,
  bool wasEdited = false,
}) {
  return TimeSession(
    id: id,
    workspaceId: workspaceId,
    projectId: projectId,
    subProjectId: subProjectId,
    taskId: taskId,
    startUtc: start,
    endUtc: end,
    startOffsetMinutes: startOffset,
    endOffsetMinutes: end == null ? null : (endOffset ?? startOffset),
    comment: comment,
    isManuallyAdded: isManuallyAdded,
    wasEdited: wasEdited,
    createdAt: start,
    updatedAt: start,
  );
}
