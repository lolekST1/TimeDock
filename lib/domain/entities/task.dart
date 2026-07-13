import 'package:flutter/foundation.dart';

/// A unit of work under a project (optionally under a sub-project).
/// The Jira id and the long-lived note live here; per-session remarks
/// belong to [TimeSession.comment] instead.
@immutable
class Task {
  const Task({
    required this.id,
    required this.projectId,
    this.subProjectId,
    required this.name,
    this.jiraId,
    this.note,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String? subProjectId;
  final String name;
  final String? jiraId;
  final String? note;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task copyWith({
    String? subProjectId,
    String? name,
    String? jiraId,
    String? note,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id,
      projectId: projectId,
      subProjectId: subProjectId ?? this.subProjectId,
      name: name ?? this.name,
      jiraId: jiraId ?? this.jiraId,
      note: note ?? this.note,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) => other is Task && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
