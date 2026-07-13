import 'package:flutter/foundation.dart';

@immutable
class Workspace {
  const Workspace({
    required this.id,
    required this.name,
    required this.colorSeed,
    this.sortOrder = 0,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;

  /// ARGB seed color for the workspace's Material 3 color scheme.
  final int colorSeed;
  final int sortOrder;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  Workspace copyWith({
    String? name,
    int? colorSeed,
    int? sortOrder,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return Workspace(
      id: id,
      name: name ?? this.name,
      colorSeed: colorSeed ?? this.colorSeed,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) => other is Workspace && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
