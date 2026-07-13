import 'package:flutter/foundation.dart';

@immutable
class Project {
  const Project({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.color,
    this.isFavorite = false,
    this.isHidden = false,
    this.isArchived = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String workspaceId;
  final String name;

  /// ARGB color used for tiles, timeline blocks and reports.
  final int color;

  final bool isFavorite;

  /// Hidden: not shown on the home screen, but time can still be logged
  /// against it (e.g. via search). Archived: excluded from logging entirely,
  /// visible only in history and reports.
  final bool isHidden;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project copyWith({
    String? name,
    int? color,
    bool? isFavorite,
    bool? isHidden,
    bool? isArchived,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id,
      workspaceId: workspaceId,
      name: name ?? this.name,
      color: color ?? this.color,
      isFavorite: isFavorite ?? this.isFavorite,
      isHidden: isHidden ?? this.isHidden,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) => other is Project && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
