import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/td_card.dart';
import '../../../core/ui/td_tokens.dart';
import '../../../domain/repositories/session_repository.dart';
import '../../app_state/app_providers.dart';
import '../../app_state/context_label.dart';

/// A "recently used" row: a full project→sub-project→task context, with the
/// project colour on the left and a prominent play button. One tap restarts the
/// timer in exactly that context.
class RecentContextTile extends ConsumerWidget {
  const RecentContextTile({super.key, required this.context});

  final SessionContext context;

  @override
  Widget build(BuildContext buildContext, WidgetRef ref) {
    final label = ref.watch(contextLabelProvider(context)).valueOrNull;
    if (label == null) return const SizedBox.shrink();

    final td = buildContext.td;
    final isDark = Theme.of(buildContext).brightness == Brightness.dark;
    final color = Color(label.color);
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;
    // A wash of the project colour gives each row its own identity and lifts it
    // off the canvas — no more flat white-on-grey.
    final tint = Color.alphaBlend(
        color.withValues(alpha: isDark ? 0.18 : 0.10), td.card);
    final detail = [
      if (label.subProjectName != null) label.subProjectName!,
      if (label.taskName != null) label.taskName!,
    ].join(' › ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: TdCard(
        padding: EdgeInsets.zero,
        clip: true,
        color: tint,
        borderColor: color.withValues(alpha: isDark ? 0.42 : 0.30),
        onTap: () => _start(buildContext, ref),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 11, 11),
                child: Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label.projectName.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: onColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.projectName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    if (detail.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: td.faint, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: onColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start(BuildContext buildContext, WidgetRef ref) async {
    unawaited(HapticFeedback.selectionClick());
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
