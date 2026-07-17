import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/project.dart';
import '../../../domain/repositories/session_repository.dart';
import '../../app_state/app_providers.dart';
import 'project_sheet.dart';

/// A project on the home grid. Tap = start the timer immediately (one tap,
/// zero questions). Long-press = open the sheet to pick a sub-project/task or
/// manage the project.
class ProjectTile extends ConsumerWidget {
  const ProjectTile({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(project.color);
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.36),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _start(context, ref),
          onLongPress: () => showProjectSheet(context, project),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.16),
                  Colors.white.withValues(alpha: 0),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    height: 16,
                    child: project.isFavorite
                        ? Icon(Icons.star_rounded, size: 16, color: onColor)
                        : null,
                  ),
                  Flexible(
                    child: Text(
                      project.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: onColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.1,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    unawaited(HapticFeedback.selectionClick());
    await ref.read(timerServiceProvider).start(SessionContext(
          workspaceId: project.workspaceId,
          projectId: project.id,
        ));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Start: ${project.name}'),
          duration: const Duration(seconds: 1),
        ));
    }
  }
}
