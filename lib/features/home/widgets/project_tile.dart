import 'package:flutter/material.dart';
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

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _start(context, ref),
        onLongPress: () => showProjectSheet(context, project),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (project.isFavorite)
                    Icon(Icons.star_rounded, size: 18, color: onColor)
                  else
                    const SizedBox(height: 18),
                ],
              ),
              Text(
                project.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
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
