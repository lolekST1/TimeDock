import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/backup_service.dart';
import '../../data/export_builder.dart';
import '../../data/file_store.dart';
import '../../data/providers.dart';

final exportBuilderProvider = Provider<ExportBuilder>((ref) => ExportBuilder(
      workspaces: ref.watch(workspaceRepositoryProvider),
      projects: ref.watch(projectRepositoryProvider),
      subProjects: ref.watch(subProjectRepositoryProvider),
      tasks: ref.watch(taskRepositoryProvider),
      sessions: ref.watch(sessionRepositoryProvider),
    ));

final backupServiceProvider =
    Provider<BackupService>((ref) => BackupService(ref.watch(databaseProvider)));

final fileStoreProvider = Provider<FileStore>((ref) => const FileStore());
