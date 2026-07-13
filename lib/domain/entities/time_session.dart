import 'package:flutter/foundation.dart';

/// A single measured (or manually entered) span of work.
///
/// Times are stored as UTC instants plus the local UTC offset captured at the
/// moment the event happened, so history renders in the wall-clock time the
/// user actually experienced, and durations stay correct across DST changes.
///
/// `endUtc == null` means the session is the currently running timer — the
/// database record itself is the source of truth for the active timer.
@immutable
class TimeSession {
  const TimeSession({
    required this.id,
    required this.workspaceId,
    required this.projectId,
    this.subProjectId,
    this.taskId,
    required this.startUtc,
    this.endUtc,
    required this.startOffsetMinutes,
    this.endOffsetMinutes,
    this.comment,
    this.isManuallyAdded = false,
    this.wasEdited = false,
    required this.createdAt,
    required this.updatedAt,
  })  : assert(endUtc == null || endOffsetMinutes != null,
            'a finished session must carry its end offset');

  final String id;
  final String workspaceId;
  final String projectId;
  final String? subProjectId;
  final String? taskId;
  final DateTime startUtc;
  final DateTime? endUtc;
  final int startOffsetMinutes;
  final int? endOffsetMinutes;

  /// What was actually done during this particular session; distinct from the
  /// long-lived note on the task.
  final String? comment;

  final bool isManuallyAdded;
  final bool wasEdited;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isRunning => endUtc == null;

  /// Duration is derived, never stored — single source of truth.
  /// For a running session pass [now] (UTC) to get the elapsed time.
  Duration durationAt(DateTime now) => (endUtc ?? now).difference(startUtc);

  /// Duration of a finished session.
  Duration get duration {
    final end = endUtc;
    assert(end != null, 'duration of a running session needs durationAt(now)');
    return end!.difference(startUtc);
  }

  /// Start rendered in the wall-clock time captured at start.
  DateTime get startLocal =>
      startUtc.add(Duration(minutes: startOffsetMinutes));

  /// End rendered in the wall-clock time captured at end (null while running).
  DateTime? get endLocal =>
      endUtc?.add(Duration(minutes: endOffsetMinutes ?? startOffsetMinutes));

  TimeSession copyWith({
    String? workspaceId,
    String? projectId,
    Object? subProjectId = _sentinel,
    Object? taskId = _sentinel,
    DateTime? startUtc,
    Object? endUtc = _sentinel,
    int? startOffsetMinutes,
    Object? endOffsetMinutes = _sentinel,
    Object? comment = _sentinel,
    bool? isManuallyAdded,
    bool? wasEdited,
    DateTime? updatedAt,
  }) {
    return TimeSession(
      id: id,
      workspaceId: workspaceId ?? this.workspaceId,
      projectId: projectId ?? this.projectId,
      subProjectId: subProjectId == _sentinel
          ? this.subProjectId
          : subProjectId as String?,
      taskId: taskId == _sentinel ? this.taskId : taskId as String?,
      startUtc: startUtc ?? this.startUtc,
      endUtc: endUtc == _sentinel ? this.endUtc : endUtc as DateTime?,
      startOffsetMinutes: startOffsetMinutes ?? this.startOffsetMinutes,
      endOffsetMinutes: endOffsetMinutes == _sentinel
          ? this.endOffsetMinutes
          : endOffsetMinutes as int?,
      comment: comment == _sentinel ? this.comment : comment as String?,
      isManuallyAdded: isManuallyAdded ?? this.isManuallyAdded,
      wasEdited: wasEdited ?? this.wasEdited,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) => other is TimeSession && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

const Object _sentinel = Object();
