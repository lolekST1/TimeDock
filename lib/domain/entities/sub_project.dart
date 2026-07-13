import 'package:flutter/foundation.dart';

@immutable
class SubProject {
  const SubProject({
    required this.id,
    required this.projectId,
    required this.name,
    this.isArchived = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String name;
  final bool isArchived;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubProject copyWith({
    String? name,
    bool? isArchived,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return SubProject(
      id: id,
      projectId: projectId,
      name: name ?? this.name,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) => other is SubProject && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
