import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/repositories/session_repository.dart';
import '../../app_state/app_providers.dart';
import '../../app_state/context_label.dart';

/// A "recently used" row: a full project→sub-project→task context.
/// One tap restarts the timer in exactly that context.
class RecentContextTile extends ConsumerWidget {
  const RecentContextTile({super.key, required this.context});

  final SessionContext context;

  @override
  Widget build(BuildContext buildContext, WidgetRef ref) {
    final label = ref.watch(contextLabelProvider(context)).valueOrNull;
    if (label == null) return const SizedBox.shrink();

    final color = Color(label.color);
    return Card(
      margin: const EdgeInsets.only(right: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _start(buildContext, ref),
        child: Container(
          width: 190,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label.projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                [
                  if (label.subProjectName != null) label.subProjectName!,
                  if (label.taskName != null) label.taskName!,
                ].join(' › '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(buildContext).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start(BuildContext buildContext, WidgetRef ref) async {
    await ref.read(timerServiceProvider).start(context);
    if (buildContext.mounted) {
      ScaffoldMessenger.of(buildContext)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Start'),
          duration: Duration(seconds: 1),
        ));
    }
  }
}
