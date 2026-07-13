import 'package:drift/drift.dart';

import '../../domain/entities/project.dart';
import '../../domain/entities/sub_project.dart';
import '../../domain/entities/task.dart';
import '../../domain/entities/time_session.dart';
import '../../domain/entities/workspace.dart';
import 'database.dart';

DateTime _utc(int millis) =>
    DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

extension WorkspaceRowMapper on WorkspaceRow {
  Workspace toEntity() => Workspace(
        id: id,
        name: name,
        colorSeed: colorSeed,
        sortOrder: sortOrder,
        isArchived: isArchived,
        createdAt: _utc(createdAtMillis),
        updatedAt: _utc(updatedAtMillis),
      );
}

extension WorkspaceEntityMapper on Workspace {
  WorkspacesCompanion toCompanion() => WorkspacesCompanion(
        id: Value(id),
        name: Value(name),
        colorSeed: Value(colorSeed),
        sortOrder: Value(sortOrder),
        isArchived: Value(isArchived),
        createdAtMillis: Value(createdAt.millisecondsSinceEpoch),
        updatedAtMillis: Value(updatedAt.millisecondsSinceEpoch),
      );
}

extension ProjectRowMapper on ProjectRow {
  Project toEntity() => Project(
        id: id,
        workspaceId: workspaceId,
        name: name,
        color: color,
        isFavorite: isFavorite,
        isHidden: isHidden,
        isArchived: isArchived,
        sortOrder: sortOrder,
        createdAt: _utc(createdAtMillis),
        updatedAt: _utc(updatedAtMillis),
      );
}

extension ProjectEntityMapper on Project {
  ProjectsCompanion toCompanion() => ProjectsCompanion(
        id: Value(id),
        workspaceId: Value(workspaceId),
        name: Value(name),
        color: Value(color),
        isFavorite: Value(isFavorite),
        isHidden: Value(isHidden),
        isArchived: Value(isArchived),
        sortOrder: Value(sortOrder),
        createdAtMillis: Value(createdAt.millisecondsSinceEpoch),
        updatedAtMillis: Value(updatedAt.millisecondsSinceEpoch),
      );
}

extension SubProjectRowMapper on SubProjectRow {
  SubProject toEntity() => SubProject(
        id: id,
        projectId: projectId,
        name: name,
        isArchived: isArchived,
        sortOrder: sortOrder,
        createdAt: _utc(createdAtMillis),
        updatedAt: _utc(updatedAtMillis),
      );
}

extension SubProjectEntityMapper on SubProject {
  SubProjectsCompanion toCompanion() => SubProjectsCompanion(
        id: Value(id),
        projectId: Value(projectId),
        name: Value(name),
        isArchived: Value(isArchived),
        sortOrder: Value(sortOrder),
        createdAtMillis: Value(createdAt.millisecondsSinceEpoch),
        updatedAtMillis: Value(updatedAt.millisecondsSinceEpoch),
      );
}

extension TaskRowMapper on TaskRow {
  Task toEntity() => Task(
        id: id,
        projectId: projectId,
        subProjectId: subProjectId,
        name: name,
        jiraId: jiraId,
        note: note,
        isArchived: isArchived,
        createdAt: _utc(createdAtMillis),
        updatedAt: _utc(updatedAtMillis),
      );
}

extension TaskEntityMapper on Task {
  TasksCompanion toCompanion() => TasksCompanion(
        id: Value(id),
        projectId: Value(projectId),
        subProjectId: Value(subProjectId),
        name: Value(name),
        jiraId: Value(jiraId),
        note: Value(note),
        isArchived: Value(isArchived),
        createdAtMillis: Value(createdAt.millisecondsSinceEpoch),
        updatedAtMillis: Value(updatedAt.millisecondsSinceEpoch),
      );
}

extension TimeSessionRowMapper on TimeSessionRow {
  TimeSession toEntity() => TimeSession(
        id: id,
        workspaceId: workspaceId,
        projectId: projectId,
        subProjectId: subProjectId,
        taskId: taskId,
        startUtc: _utc(startUtcMillis),
        endUtc: endUtcMillis == null ? null : _utc(endUtcMillis!),
        startOffsetMinutes: startOffsetMinutes,
        endOffsetMinutes: endOffsetMinutes,
        comment: comment,
        isManuallyAdded: isManuallyAdded,
        wasEdited: wasEdited,
        createdAt: _utc(createdAtMillis),
        updatedAt: _utc(updatedAtMillis),
      );
}

extension TimeSessionEntityMapper on TimeSession {
  TimeSessionsCompanion toCompanion() => TimeSessionsCompanion(
        id: Value(id),
        workspaceId: Value(workspaceId),
        projectId: Value(projectId),
        subProjectId: Value(subProjectId),
        taskId: Value(taskId),
        startUtcMillis: Value(startUtc.millisecondsSinceEpoch),
        endUtcMillis: Value(endUtc?.millisecondsSinceEpoch),
        startOffsetMinutes: Value(startOffsetMinutes),
        endOffsetMinutes: Value(endOffsetMinutes),
        comment: Value(comment),
        isManuallyAdded: Value(isManuallyAdded),
        wasEdited: Value(wasEdited),
        createdAtMillis: Value(createdAt.millisecondsSinceEpoch),
        updatedAtMillis: Value(updatedAt.millisecondsSinceEpoch),
      );
}
