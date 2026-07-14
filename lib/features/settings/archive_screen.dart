import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../app_state/app_providers.dart';

/// Lists archived projects for a workspace and lets the user restore them
/// (or delete those without any sessions).
class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived =
        ref.watch(archivedProjectsProvider(workspaceId)).valueOrNull ??
            const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Zarchiwizowane projekty')),
      body: archived.isEmpty
          ? const Center(child: Text('Brak zarchiwizowanych projektów'))
          : ListView(
              children: [
                for (final p in archived)
                  ListTile(
                    leading: CircleAvatar(
                        radius: 10, backgroundColor: Color(p.color)),
                    title: Text(p.name),
                    trailing: FilledButton.tonalIcon(
                      icon: const Icon(Icons.unarchive_outlined),
                      label: const Text('Przywróć'),
                      onPressed: () => ref
                          .read(projectRepositoryProvider)
                          .upsert(p.copyWith(
                              isArchived: false,
                              updatedAt: DateTime.now().toUtc())),
                    ),
                  ),
              ],
            ),
    );
  }
}
