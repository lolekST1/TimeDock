import 'package:flutter/foundation.dart';

@immutable
class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.colorSeed,
    this.sortOrder = 0,
    this.isArchived = false,
    this.weeklyGoalMinutes,
    this.exportsToTimesheet = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;

  /// ARGB seed color for the workspace's Material 3 color scheme.
  final int colorSeed;
  final int sortOrder;
  final bool isArchived;

  /// Optional weekly target in minutes; null means no goal set.
  final int? weeklyGoalMinutes;

  /// When true, this workspace's finished sessions are eligible for the
  /// worklog (timesheet) export — the future replacement for Tempo consumes it.
  final bool exportsToTimesheet;

  final DateTime createdAt;
  final DateTime updatedAt;

  Workspace copyWith({
    String? name,
    int? colorSeed,
    int? sortOrder,
    bool? isArchived,
    Object? weeklyGoalMinutes = _sentinel,
    bool? exportsToTimesheet,
    DateTime? updatedAt,
  }) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      colorSeed: colorSeed ?? this.colorSeed,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      weeklyGoalMinutes: weeklyGoalMinutes == _sentinel
          ? this.weeklyGoalMinutes
          : weeklyGoalMinutes as int?,
      exportsToTimesheet: exportsToTimesheet ?? this.exportsToTimesheet,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) => other is Workspace && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

const Object _sentinel = Object();
